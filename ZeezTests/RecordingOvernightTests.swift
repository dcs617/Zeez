import Testing
import CoreData
import Foundation
import AVFoundation
@testable import Zeez

/// A meter that behaves like `AVAudioRecorder`: stopped, it reads −160 dB. Tests halt it to do
/// what an interruption or a route change does to a real one.
final class FakeNoiseMeter: NoiseMeter, @unchecked Sendable {
    private let lock = NSLock()
    private let power: Float
    private let starts: Bool
    private var recording = false

    init(power: Float, starts: Bool) {
        self.power = power
        self.starts = starts
    }

    var isRecording: Bool {
        lock.lock(); defer { lock.unlock() }
        return recording
    }

    func record() -> Bool {
        lock.lock(); defer { lock.unlock() }
        recording = starts
        return starts
    }

    func stop() { halt() }

    func halt() {
        lock.lock(); recording = false; lock.unlock()
    }

    func updateMeters() {}

    func averagePower(forChannel channelNumber: Int) -> Float {
        lock.lock(); defer { lock.unlock() }
        return recording ? power : -160
    }
}

final class FakeNoiseMeterFactory: @unchecked Sendable {
    static let power: Float = -40

    private let lock = NSLock()
    private var made: [FakeNoiseMeter] = []

    var meters: [FakeNoiseMeter] {
        lock.lock(); defer { lock.unlock() }
        return made
    }

    func make() throws -> NoiseMeter {
        let meter = FakeNoiseMeter(power: Self.power, starts: true)
        lock.lock(); made.append(meter); lock.unlock()
        return meter
    }
}

final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    init(_ start: Date) {
        current = start
    }

    var now: Date {
        lock.lock(); defer { lock.unlock() }
        return current
    }

    func advance(_ seconds: TimeInterval) {
        lock.lock(); current = current.addingTimeInterval(seconds); lock.unlock()
    }
}

/// A recording keeps sampling overnight, and a gap is never quiet (2026-11-01).
///
/// Before, the monitor sampled only in the foreground, a call or a headset stopped its
/// recorder for the rest of the night, a reset of media services left it holding a dead one,
/// and a stopped recorder's −160 dB was stored as the quietest possible room. A failed save
/// was logged every five minutes and never reached the user.
@Suite("A recording runs all night", .serialized) @MainActor
struct RecordingOvernightTests {

    private static let measured = NoiseIndex.fromAveragePower(FakeNoiseMeterFactory.power)

    private final class Fixture {
        let persistence: PersistenceController
        let notifications: NotificationCenter
        let audioSession: FakeAudioSession
        let errors: ErrorManager
        let meters: FakeNoiseMeterFactory
        let clock: TestClock
        let coordinator: AudioSessionCoordinator
        let monitor: EnvironmentalMonitor
        let session: SleepSession

        init() throws {
            let persistence = PersistenceController(inMemory: true)
            let notifications = NotificationCenter()
            let audioSession = FakeAudioSession()
            let errors = ErrorManager()
            let meters = FakeNoiseMeterFactory()
            let clock = TestClock(Date(timeIntervalSince1970: 1_800_000_000))
            let coordinator = AudioSessionCoordinator(session: audioSession, notificationCenter: notifications)
            self.persistence = persistence
            self.notifications = notifications
            self.audioSession = audioSession
            self.errors = errors
            self.meters = meters
            self.clock = clock
            self.coordinator = coordinator
            monitor = EnvironmentalMonitor(persistenceController: persistence,
                                           coordinator: coordinator,
                                           microphone: FakeMicrophonePermission(granted: true),
                                           errors: errors,
                                           makeMeter: { try meters.make() },
                                           now: { clock.now })
            let context = persistence.container.viewContext
            let session = SleepSession(context: context)
            session.id = UUID()
            session.startTime = clock.now
            session.isActive = true
            self.session = session
            try context.save()
        }

        var context: NSManagedObjectContext { persistence.container.viewContext }

        /// One sample, taken once the meter has had time to hear the room.
        func sample(after seconds: TimeInterval = 60) {
            clock.advance(seconds)
            monitor.captureSample(for: session)
        }

        func noiseLevels() throws -> [Double] {
            let request: NSFetchRequest<EnvironmentalReading> = EnvironmentalReading.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \EnvironmentalReading.timestamp, ascending: true)]
            return try context.fetch(request).map(\.noiseLevel)
        }

        func post(_ name: Notification.Name, _ userInfo: [AnyHashable: Any]? = nil) {
            notifications.post(name: name, object: nil, userInfo: userInfo)
        }

        var liveMeter: Bool { meters.meters.last?.isRecording == true }
    }

    @Test("Info.plist declares background audio, so a recording runs with the phone locked")
    func backgroundAudioIsDeclared() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Zeez/Info.plist")
        let plist = try #require(try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any])
        let modes = plist["UIBackgroundModes"] as? [String] ?? []
        #expect(modes.contains("audio"), "Without it iOS suspends the app, and the recording, when the phone locks")
    }

    @Test("A meter that has stopped records not measured, not the quietest room")
    func stoppedMeterIsNotMeasured() throws {
        let fixture = try Fixture()
        try fixture.monitor.startMonitoring(for: fixture.session)

        fixture.sample()
        fixture.meters.meters.last?.halt()
        fixture.sample()

        #expect(try fixture.noiseLevels() == [Self.measured, EnvironmentalReading.notMeasured])
        fixture.monitor.stopMonitoring()
    }

    @Test("A meter that has only just started records not measured")
    func meterWarmsUpBeforeItCounts() throws {
        let fixture = try Fixture()
        try fixture.monitor.startMonitoring(for: fixture.session)

        fixture.sample(after: 0)

        #expect(try fixture.noiseLevels() == [EnvironmentalReading.notMeasured])
        fixture.monitor.stopMonitoring()
    }

    @Test("A call pauses the recording, its samples read not measured, and it resumes when the call ends")
    func callPausesAndResumes() async throws {
        let fixture = try Fixture()
        try fixture.monitor.startMonitoring(for: fixture.session)
        fixture.sample()

        // The call holds the audio hardware: the system stops the recorder, and the session
        // cannot be reactivated until it ends.
        fixture.audioSession.refusesActivation = true
        fixture.post(AVAudioSession.interruptionNotification,
                     [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue])
        fixture.meters.meters.last?.halt()
        try await AlarmTestSupport.waitUntil("the meter to stop") { !fixture.liveMeter }
        fixture.sample()

        fixture.audioSession.refusesActivation = false
        fixture.post(AVAudioSession.interruptionNotification,
                     [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue])
        try await AlarmTestSupport.waitUntil("the meter to restart") { fixture.liveMeter }
        fixture.sample()

        #expect(try fixture.noiseLevels() == [Self.measured, EnvironmentalReading.notMeasured, Self.measured])
        fixture.monitor.stopMonitoring()
    }

    @Test("When iOS never says the call ended, the next sample gets the microphone back")
    func sampleRecoversAMissedInterruptionEnd() async throws {
        let fixture = try Fixture()
        try fixture.monitor.startMonitoring(for: fixture.session)
        fixture.post(AVAudioSession.interruptionNotification,
                     [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue])
        fixture.meters.meters.last?.halt()
        try await AlarmTestSupport.waitUntil("the meter to stop") { !fixture.liveMeter }

        fixture.sample()
        try await AlarmTestSupport.waitUntil("the meter to restart") { fixture.liveMeter }
        fixture.sample()

        #expect(try fixture.noiseLevels() == [EnvironmentalReading.notMeasured, Self.measured])
        fixture.monitor.stopMonitoring()
    }

    @Test("After media services reset, a new meter starts")
    func mediaResetStartsANewMeter() async throws {
        let fixture = try Fixture()
        try fixture.monitor.startMonitoring(for: fixture.session)

        fixture.post(AVAudioSession.mediaServicesWereResetNotification)
        try await AlarmTestSupport.waitUntil("a second meter") { fixture.meters.meters.count == 2 && fixture.liveMeter }

        #expect(fixture.meters.meters.first?.isRecording == false, "The old recorder belongs to the services that reset")
        fixture.monitor.stopMonitoring()
    }

    @Test("A meter that stopped when a headset was unplugged restarts")
    func routeChangeRestartsAStoppedMeter() async throws {
        let fixture = try Fixture()
        try fixture.monitor.startMonitoring(for: fixture.session)

        fixture.meters.meters.last?.halt()
        fixture.post(AVAudioSession.routeChangeNotification,
                     [AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue])
        try await AlarmTestSupport.waitUntil("the meter to restart") { fixture.liveMeter }

        #expect(fixture.meters.meters.count == 2)
        fixture.monitor.stopMonitoring()
    }

    @Test("A sample that cannot be saved alerts once per recording, not every five minutes")
    func failedSaveAlertsOncePerRecording() throws {
        let fixture = try Fixture()
        try fixture.monitor.startMonitoring(for: fixture.session)

        // Out of the model's range, so every save of the context fails validation.
        fixture.session.cycleConsistency = 1000
        fixture.sample()
        #expect(fixture.errors.currentAlert == .saveFailed)
        fixture.errors.dismissAlert()
        fixture.sample()
        #expect(fixture.errors.currentAlert == nil)
        #expect(fixture.errors.pendingAlerts.isEmpty)

        // The failed samples are not left behind to fail every later save.
        fixture.session.cycleConsistency = 0
        fixture.sample()
        #expect(try fixture.noiseLevels() == [Self.measured])

        // The next recording alerts again.
        fixture.monitor.stopMonitoring()
        try fixture.monitor.startMonitoring(for: fixture.session)
        fixture.session.cycleConsistency = 1000
        fixture.sample()
        #expect(fixture.errors.currentAlert == .saveFailed)
        fixture.session.cycleConsistency = 0
        fixture.monitor.stopMonitoring()
    }
}
