import Testing
import Foundation
import UserNotifications
import CoreData
@testable import Zeez

/// Snooze + notification-handler scheduling tests (roadmap 2.4 step 1: the
/// `AlarmNotificationScheduling` injection extended beyond AlarmScheduler to
/// AlarmNotificationUtils and AlarmNotificationHandler).
///
/// AlarmNotificationUtils is a namespace enum, so its seams are static —
/// this suite is `.serialized` and every test restores the previous values.
@Suite("Snooze and handler scheduling", .serialized)
struct AlarmSnoozeAndHandlerTests {

    /// Runs `body` with Utils pointed at a fake center + in-memory container.
    private func withUtilsSeams<T>(
        _ body: (FakeNotificationCenter, PersistenceController) async throws -> T
    ) async rethrows -> T {
        let fake = FakeNotificationCenter()
        let controller = PersistenceController(inMemory: true)
        let previousCenter = AlarmNotificationUtils.notificationCenter
        let previousContainer = AlarmNotificationUtils.container
        AlarmNotificationUtils.notificationCenter = fake
        AlarmNotificationUtils.container = controller.container
        defer {
            AlarmNotificationUtils.notificationCenter = previousCenter
            AlarmNotificationUtils.container = previousContainer
        }
        return try await body(fake, controller)
    }

    private func snoozes(_ fake: FakeNotificationCenter, _ id: String) -> [UNNotificationRequest] {
        fake.pending.filter { $0.identifier.hasPrefix("snooze-\(id)-") }
    }

    private func snoozeChain(_ fake: FakeNotificationCenter, _ id: String) -> [UNNotificationRequest] {
        fake.pending.filter { $0.identifier.contains("alarm-\(id)-fu-snz-") }
    }

    // MARK: - Snooze (AlarmNotificationUtils)

    @Test func snoozeSchedulesAlarmConfiguredDurationAndPreArmedChain() async throws {
        try await withUtilsSeams { fake, controller in
            let alarm = try AlarmTestSupport.makeAlarm(in: controller.container.viewContext, days: [2])
            let id = alarm.id!.uuidString

            AlarmNotificationUtils.scheduleSnooze(for: id)

            // Snooze fire uses the alarm's configured 9 minutes.
            try await AlarmTestSupport.waitUntil("snooze request") {
                self.snoozes(fake, id).count == 1
            }
            let snooze = try #require(snoozes(fake, id).first)
            let trigger = try #require(snooze.trigger as? UNTimeIntervalNotificationTrigger)
            #expect(trigger.timeInterval == 9 * 60)
            #expect(snooze.content.userInfo["type"] as? String == "main",
                    "Snooze fire must count as a main so follow-ups re-arm")

            // A follow-up chain is pre-armed BEHIND the snooze so Heavy Sleeper
            // works when the snooze fires with the app killed (1.1).
            try await AlarmTestSupport.waitUntil("pre-armed snooze chain") {
                self.snoozeChain(fake, id).count == AlarmNotificationUtils.maxPreScheduledFollowUps
            }
            for request in snoozeChain(fake, id) {
                let chainTrigger = try #require(request.trigger as? UNTimeIntervalNotificationTrigger)
                #expect(chainTrigger.timeInterval > 9 * 60,
                        "Chain entries fire after the snooze itself")
            }
        }
    }

    @Test func snoozeForUnknownAlarmFallsBackToBasicSnooze() async throws {
        try await withUtilsSeams { fake, _ in
            let ghostID = UUID().uuidString

            AlarmNotificationUtils.scheduleSnooze(for: ghostID, minutes: 5)

            try await AlarmTestSupport.waitUntil("basic snooze") {
                self.snoozes(fake, ghostID).count == 1
            }
            let snooze = try #require(snoozes(fake, ghostID).first)
            let trigger = try #require(snooze.trigger as? UNTimeIntervalNotificationTrigger)
            #expect(trigger.timeInterval == 5 * 60)
            #expect(snoozeChain(fake, ghostID).isEmpty,
                    "No chain without alarm settings to derive it from")
        }
    }

    @Test func snoozeCancelsThePendingFollowUpsItSupersedes() async throws {
        try await withUtilsSeams { fake, controller in
            let alarm = try AlarmTestSupport.makeAlarm(in: controller.container.viewContext, days: [3])
            let id = alarm.id!.uuidString

            // Simulate an in-flight chain from the fire that is being snoozed.
            for n in 1...4 {
                fake.add(UNNotificationRequest(
                    identifier: "alarm-\(id)-fu-\(n)-999",
                    content: UNMutableNotificationContent(),
                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: Double(n) * 60, repeats: false)
                ), withCompletionHandler: nil)
            }

            AlarmNotificationUtils.scheduleSnooze(for: id)

            try await AlarmTestSupport.waitUntil("old chain gone, snooze armed") {
                let oldChain = fake.pending.filter { $0.identifier.hasPrefix("alarm-\(id)-fu-") && !$0.identifier.contains("-fu-snz-") }
                return oldChain.isEmpty && self.snoozes(fake, id).count == 1
            }
        }
    }

    // MARK: - Handler follow-ups (AlarmNotificationHandler)

    @Test func handlerSchedulesDynamicChainAtCadenceThroughInjectedCenter() async throws {
        let fake = FakeNotificationCenter()
        let controller = PersistenceController(inMemory: true)
        let handler = AlarmNotificationHandler(notificationCenter: fake, container: controller.container)
        let id = UUID().uuidString

        handler.scheduleFollowUps(alarmId: id, cadence: 60, maxCount: 6, snapshot: nil)

        try await AlarmTestSupport.waitUntil("6 dynamic follow-ups") {
            fake.pending.filter { $0.identifier.hasPrefix("alarm-\(id)-fu-") }.count == 6
        }
        let intervals = fake.pending
            .filter { $0.identifier.hasPrefix("alarm-\(id)-fu-") }
            .compactMap { ($0.trigger as? UNTimeIntervalNotificationTrigger)?.timeInterval }
            .sorted()
        #expect(intervals == [60, 120, 180, 240, 300, 360])
    }

    @Test func handlerCancelFollowUpsRemovesOnlyThatAlarmsChain() async throws {
        let fake = FakeNotificationCenter()
        let controller = PersistenceController(inMemory: true)
        let handler = AlarmNotificationHandler(notificationCenter: fake, container: controller.container)
        let victim = UUID().uuidString
        let bystander = UUID().uuidString

        handler.scheduleFollowUps(alarmId: victim, cadence: 60, maxCount: 4, snapshot: nil)
        handler.scheduleFollowUps(alarmId: bystander, cadence: 60, maxCount: 4, snapshot: nil)
        try await AlarmTestSupport.waitUntil("both chains armed") {
            fake.pending.filter { $0.identifier.contains("-fu-") }.count == 8
        }

        handler.cancelFollowUps(for: victim)

        try await AlarmTestSupport.waitUntil("victim chain removed, bystander intact") {
            fake.pending.filter { $0.identifier.contains("alarm-\(victim)-fu-") }.isEmpty &&
            fake.pending.filter { $0.identifier.contains("alarm-\(bystander)-fu-") }.count == 4
        }
    }

    // MARK: - In-app audio (AlarmNotificationHandler)

    /// A handler whose audio goes to fake players, and the alarm's id string.
    private func audioHandler(vibrationOnly: Bool) throws
        -> (handler: AlarmNotificationHandler, audio: AlarmAudioController, players: FakeAudioPlayerFactory, alarmId: String) {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let alarm = try AlarmTestSupport.makeAlarm(in: context, vibrationOnly: vibrationOnly)
        let alarmId = try #require(context.performAndWait { alarm.id?.uuidString })
        let players = FakeAudioPlayerFactory()
        let audio = AlarmAudioController(session: FakeAudioSession(), players: players)
        let handler = AlarmNotificationHandler(notificationCenter: FakeNotificationCenter(),
                                               container: controller.container, audio: audio)
        return (handler, audio, players, alarmId)
    }

    /// The handler starts the loop before `ActiveAlarmView` appears, and the view only adds
    /// vibration for a vibration-only alarm. A loop started here rang until Stop.
    @Test("A vibration-only alarm that rings in the app plays no audio")
    func vibrationOnlyAlarmPlaysNoAudio() throws {
        let (handler, audio, players, alarmId) = try audioHandler(vibrationOnly: true)

        handler.startContinuousAudio(alarmId: alarmId)

        #expect(players.attempts.isEmpty, "No sound file is even opened")
        #expect(!audio.isPlaying)
    }

    @Test("An alarm with sound starts the in-app loop")
    func alarmWithSoundStartsTheLoop() throws {
        let (handler, audio, players, alarmId) = try audioHandler(vibrationOnly: false)

        handler.startContinuousAudio(alarmId: alarmId)

        #expect(audio.isPlaying)
        #expect(players.players.last?.fileName == "Zeez_Long_Default.caf")
        #expect(players.players.last?.isPlaying == true)
        audio.stop()
    }

    /// Settings cannot be read for a deleted alarm or a malformed id; ringing is the safe side.
    @Test("An alarm whose settings cannot be read still rings")
    func unreadableAlarmStillRings() throws {
        let (handler, audio, _, _) = try audioHandler(vibrationOnly: true)

        handler.startContinuousAudio(alarmId: UUID().uuidString)

        #expect(audio.isPlaying)
        audio.stop()
    }

    /// A banner tap on any notification reaches the handler, and one that is not an alarm (a
    /// Learn reminder) carries no `alarmID`. The empty id could not be read, so the long sound
    /// looped with no alarm screen to stop it. `didReceive` needs a real response, so this
    /// pins the guard inside the audio start.
    @Test("A notification without an alarm ID plays no audio")
    func notificationWithoutAlarmIDPlaysNoAudio() throws {
        let (handler, audio, players, _) = try audioHandler(vibrationOnly: false)

        handler.startContinuousAudio(alarmId: "")

        #expect(players.attempts.isEmpty, "No sound file is even opened")
        #expect(!audio.isPlaying)
    }

    // MARK: - Watch haptics (AlarmNotificationHandler)

    /// A handler whose watch messages go to a fake session, and a watch-haptics alarm's snapshot.
    private func hapticsHandler(reachable: Bool) throws
        -> (handler: AlarmNotificationHandler, watch: WatchConnectivityHandler, session: FakeWatchSession, snapshot: AlarmSnapshot) {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let alarm = try AlarmTestSupport.makeAlarm(in: context, watchHaptics: true)
        let snapshot = try #require(context.performAndWait { AlarmSnapshot(alarm) })
        let session = FakeWatchSession(reachable: reachable)
        let watch = WatchConnectivityHandler(session: session, container: controller.container)
        let handler = AlarmNotificationHandler(notificationCenter: FakeNotificationCenter(),
                                               container: controller.container, watch: watch)
        return (handler, watch, session, snapshot)
    }

    private func commands(_ session: FakeWatchSession) -> [String?] {
        session.sent.map { $0.payload["command"] as? String }
    }

    /// The gate was a cached flag: "activated" after activation, then "reachable" after a
    /// watch-state change, and never updated when the watch app opened. A fresh handler's
    /// flag was false, and a stale one held back haptics from a reachable watch.
    @Test("A ringing alarm with watch haptics buzzes a reachable watch, and Stop stops it")
    func watchHapticsReachAReachableWatch() throws {
        let (handler, _, session, snapshot) = try hapticsHandler(reachable: true)

        handler.scheduleFollowUps(alarmId: snapshot.idString, cadence: 60, maxCount: 1, snapshot: snapshot)
        #expect(commands(session) == [WatchMessageType.wakePattern.rawValue])

        handler.cancelFollowUps(for: snapshot.idString)
        #expect(commands(session) == [WatchMessageType.wakePattern.rawValue, WatchMessageType.stopPattern.rawValue])
    }

    @Test("A ringing alarm sends nothing to an unreachable watch, and queues nothing")
    func watchHapticsSkipAnUnreachableWatch() throws {
        let (handler, watch, session, snapshot) = try hapticsHandler(reachable: false)

        handler.scheduleFollowUps(alarmId: snapshot.idString, cadence: 60, maxCount: 1, snapshot: snapshot)
        handler.cancelFollowUps(for: snapshot.idString)

        #expect(session.sent.isEmpty)
        #expect(watch.queuedMessageCount == 0)
    }
}
