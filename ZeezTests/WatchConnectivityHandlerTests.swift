import Testing
import Foundation
import CoreData
import WatchConnectivity
@testable import Zeez

/// In-memory stand-in for WCSession (second-audit D2a). Thread-safe: the handler sends
/// from a background context's queue. Records the transport each message took, and
/// answers sends with a reply or with the error a test sets.
final class FakeWatchSession: WatchSessionProtocol, @unchecked Sendable {
    enum Transport: Equatable {
        case message
        case applicationContext
    }

    struct Sent {
        let transport: Transport
        let payload: [String: Any]
    }

    private let lock = NSLock()
    private let supported: Bool
    private var reachable: Bool
    private var paired = true
    private var watchAppInstalled = true
    private var messageError: Error?
    private var applicationContextError: Error?
    private var sentStorage: [Sent] = []
    private var activationCount = 0
    private weak var storedDelegate: WCSessionDelegate?

    init(supported: Bool = true, reachable: Bool = true) {
        self.supported = supported
        self.reachable = reachable
    }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock(); defer { lock.unlock() }
        return body()
    }

    /// Every send attempted, in order, including ones the fake then failed.
    var sent: [Sent] { locked { sentStorage } }
    var activations: Int { locked { activationCount } }

    /// When set, `sendMessage` calls its error handler with this instead of replying.
    func failMessages(with error: Error) { locked { messageError = error } }
    /// When set, `updateApplicationContext` throws this.
    func failApplicationContext(with error: Error) { locked { applicationContextError = error } }
    func setPaired(_ value: Bool) { locked { paired = value } }
    func setWatchAppInstalled(_ value: Bool) { locked { watchAppInstalled = value } }

    // MARK: WatchSessionProtocol

    var isSupported: Bool { supported }

    var delegate: WCSessionDelegate? {
        get { locked { storedDelegate } }
        set { locked { storedDelegate = newValue } }
    }

    func activate() { locked { activationCount += 1 } }

    var isReachable: Bool { locked { reachable } }
    var isPaired: Bool { locked { paired } }
    var isWatchAppInstalled: Bool { locked { watchAppInstalled } }

    func sendMessage(_ message: [String: Any],
                     replyHandler: (([String: Any]) -> Void)?,
                     errorHandler: ((Error) -> Void)?) {
        let error: Error? = locked {
            sentStorage.append(Sent(transport: .message, payload: message))
            return messageError
        }
        if let error {
            errorHandler?(error)
        } else {
            replyHandler?(["status": "received"])
        }
    }

    func updateApplicationContext(_ applicationContext: [String: Any]) throws {
        let error: Error? = locked {
            sentStorage.append(Sent(transport: .applicationContext, payload: applicationContext))
            return applicationContextError
        }
        if let error { throw error }
    }
}

/// Collects what a callback hands over, on whichever queue it runs.
private final class Recorder<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Value] = []

    func append(_ value: Value) {
        lock.lock(); storage.append(value); lock.unlock()
    }

    var values: [Value] {
        lock.lock(); defer { lock.unlock() }
        return storage
    }
}

/// The phone side of the watch transport (second-audit D2a). `WatchPayloadBuilderTests` covers
/// what the payloads contain; this covers which transport carries them and how the phone
/// answers the watch's requests, which nothing tested while the handler owned `WCSession.default`.
@Suite("Watch connectivity handler")
struct WatchConnectivityHandlerTests {

    private static let everyDay: Set<Int> = Set(1...7)

    /// A completed eight-hour night and an alarm that rings within a day.
    private func seedNightAndAlarm(in container: NSPersistentContainer) throws {
        let context = container.viewContext
        let now = Date()
        try context.performAndWait {
            let session = SleepSession(context: context)
            session.id = UUID()
            session.startTime = now.addingTimeInterval(-10 * 3600)
            session.endTime = now.addingTimeInterval(-2 * 3600)
            session.isActive = false
            session.qualityScore = 1.0  // the no-estimate sentinel
            try context.save()
        }
        try AlarmTestSupport.makeAlarm(in: context, name: "Wake", time: now.addingTimeInterval(3600),
                                       days: Self.everyDay)
    }

    private func message(_ priority: MessagePriority) -> WatchMessage {
        WatchMessage(type: .wakePattern, data: ["pattern": HapticPattern.moderate.rawValue], priority: priority)
    }

    // MARK: - Priority → transport

    @Test("A high-priority message goes out as an interactive message when the watch is reachable")
    func highPriorityIsSentInteractively() {
        let session = FakeWatchSession(reachable: true)
        let handler = WatchConnectivityHandler(session: session, container: PersistenceController(inMemory: true).container)
        let completions = Recorder<Bool>()

        handler.sendMessage(message(.high)) { completions.append($0) }

        #expect(session.sent.map(\.transport) == [.message])
        #expect(session.sent.first?.payload["command"] as? String == WatchMessageType.wakePattern.rawValue)
        #expect(completions.values == [true])
    }

    /// `sendMessage` needs the watch app running in the foreground. Calling it on an
    /// unreachable watch only fails after a timeout, and a wake pattern that late is wrong.
    @Test("A high-priority message is refused, not sent, while the watch is unreachable")
    func highPriorityIsRefusedWhenUnreachable() {
        let session = FakeWatchSession(reachable: false)
        let handler = WatchConnectivityHandler(session: session, container: PersistenceController(inMemory: true).container)
        let completions = Recorder<Bool>()

        handler.sendMessage(message(.high)) { completions.append($0) }

        #expect(session.sent.isEmpty)
        #expect(completions.values == [false])
    }

    /// The application context is delivered whenever the watch app next runs, so medium and
    /// low priority must not wait for reachability.
    @Test("Medium and low priority go through the application context, reachable or not")
    func lowerPrioritiesUseApplicationContext() {
        let session = FakeWatchSession(reachable: false)
        let handler = WatchConnectivityHandler(session: session, container: PersistenceController(inMemory: true).container)
        let completions = Recorder<Bool>()

        handler.sendMessage(message(.medium)) { completions.append($0) }
        handler.sendMessage(message(.low)) { completions.append($0) }

        #expect(session.sent.map(\.transport) == [.applicationContext, .applicationContext])
        #expect(completions.values == [true, true])
    }

    @Test("A send that fails reports failure on either transport")
    func failedSendsReportFailure() {
        let session = FakeWatchSession(reachable: true)
        session.failMessages(with: WCError(.notReachable))
        session.failApplicationContext(with: WCError(.payloadTooLarge))
        let handler = WatchConnectivityHandler(session: session, container: PersistenceController(inMemory: true).container)
        let completions = Recorder<Bool>()

        handler.sendMessage(message(.high)) { completions.append($0) }
        handler.sendMessage(message(.medium)) { completions.append($0) }

        #expect(session.sent.map(\.transport) == [.message, .applicationContext])
        #expect(completions.values == [false, false])
    }

    // MARK: - Replies to the watch

    /// The watch's `requestLatestData` sends only the command, with no `requestType`.
    @Test("The watch's data request is answered with the night and the next alarm")
    func dataRequestRepliesWithBothPayloads() async throws {
        let container = PersistenceController(inMemory: true).container
        try seedNightAndAlarm(in: container)
        let session = FakeWatchSession()
        let handler = WatchConnectivityHandler(session: session, container: container)
        let replies = Recorder<[String: Any]>()

        handler.handleWatchMessage(["command": WatchMessageType.requestData.rawValue]) { replies.append($0) }

        try await AlarmTestSupport.waitUntil("the data reply") { !replies.values.isEmpty }
        let reply = WatchSyncEnvelope(dictionary: try #require(replies.values.first))
        let summary = try #require(reply.sleepSummary)
        #expect(abs(summary.lastNightDuration - 8 * 3600) < 1)
        #expect(reply.alarmStatus?.isEnabled == true)
        #expect(session.sent.isEmpty, "A reply answers the request; it is not also pushed")
    }

    @Test("A sleep or alarm request is answered with only that payload",
          arguments: [("sleep", true, false), ("alarm", false, true)])
    func typedDataRequestRepliesWithOnePayload(requestType: String, expectsSleep: Bool, expectsAlarm: Bool) async throws {
        let container = PersistenceController(inMemory: true).container
        try seedNightAndAlarm(in: container)
        let handler = WatchConnectivityHandler(session: FakeWatchSession(), container: container)
        let replies = Recorder<[String: Any]>()

        handler.handleWatchMessage(["command": WatchMessageType.requestData.rawValue,
                                    "requestType": requestType]) { replies.append($0) }

        try await AlarmTestSupport.waitUntil("the \(requestType) reply") { !replies.values.isEmpty }
        let reply = WatchSyncEnvelope(dictionary: try #require(replies.values.first))
        #expect((reply.sleepSummary != nil) == expectsSleep)
        #expect((reply.alarmStatus != nil) == expectsAlarm)
    }

    @Test("A status request reports the session's connection state")
    func statusRequestReportsConnection() throws {
        let session = FakeWatchSession(reachable: true)
        session.setPaired(true)
        session.setWatchAppInstalled(false)
        let handler = WatchConnectivityHandler(session: session, container: PersistenceController(inMemory: true).container)
        let replies = Recorder<[String: Any]>()

        handler.handleWatchMessage(["command": WatchMessageType.requestData.rawValue,
                                    "requestType": "status"]) { replies.append($0) }

        let info = try #require(replies.values.first?["connectionInfo"] as? [String: Any])
        #expect(info["isReachable"] as? Bool == true)
        #expect(info["isPaired"] as? Bool == true)
        #expect(info["isWatchAppInstalled"] as? Bool == false)
    }

    /// A watch that sends with a reply handler waits for one; silence ends in a timeout error
    /// on the watch instead of an answer it can act on.
    @Test("Malformed and unknown requests are answered, not left to time out")
    func malformedRequestsAreAnswered() {
        let handler = WatchConnectivityHandler(session: FakeWatchSession(), container: PersistenceController(inMemory: true).container)
        let replies = Recorder<[String: Any]>()

        handler.handleWatchMessage(["requestType": "all"]) { replies.append($0) }
        handler.handleWatchMessage(["command": "notACommand"]) { replies.append($0) }
        handler.handleWatchMessage(["command": WatchMessageType.requestData.rawValue,
                                    "requestType": "notAType"]) { replies.append($0) }

        let answered = replies.values
        #expect(answered.count == 3)
        #expect(answered.first?["error"] as? String == "Invalid command")
        #expect(answered.dropFirst().first?["error"] as? String == "Unknown command")
        #expect(answered.last?.isEmpty == true)
    }

    // MARK: - Pushes

    /// `updateApplicationContext` has a single slot: a second push replaces the first before the
    /// watch reads it, so sending the night and the alarm separately delivered only the alarm (A5).
    @Test("A full sync pushes the night and the alarm in one application-context update")
    func fullSyncIsOnePush() async throws {
        let container = PersistenceController(inMemory: true).container
        try seedNightAndAlarm(in: container)
        let session = FakeWatchSession()
        let handler = WatchConnectivityHandler(session: session, container: container)

        handler.performFullSync()

        try await AlarmTestSupport.waitUntil("a push carrying the alarm") {
            session.sent.contains { WatchSyncEnvelope(dictionary: $0.payload).alarmStatus != nil }
        }
        let pushes = session.sent
        #expect(pushes.count == 1)
        #expect(pushes.first?.transport == .applicationContext)
        let envelope = WatchSyncEnvelope(dictionary: try #require(pushes.first?.payload))
        #expect(envelope.sleepSummary != nil)
        #expect(envelope.alarmStatus != nil)
    }

    /// The watch keeps the last alarm it was told about, so "nothing rings" must be sent too.
    @Test("With no enabled alarm, the alarm push is an explicit disabled status")
    func alarmPushWithNothingToRingIsDisabled() async throws {
        let container = PersistenceController(inMemory: true).container
        try AlarmTestSupport.makeAlarm(in: container.viewContext, days: Self.everyDay, enabled: false)
        let session = FakeWatchSession()
        let handler = WatchConnectivityHandler(session: session, container: container)

        handler.updateAlarmContext()

        try await AlarmTestSupport.waitUntil("the alarm push") { !session.sent.isEmpty }
        let push = try #require(session.sent.first)
        #expect(push.transport == .applicationContext)
        let status = try #require(WatchSyncEnvelope(dictionary: push.payload).alarmStatus)
        #expect(!status.isEnabled)
        #expect(status.nextAlarmTime == nil)
    }

    // MARK: - Activation

    @Test("The handler activates the session only where WatchConnectivity is supported")
    func activatesOnlyWhereSupported() {
        let supported = FakeWatchSession(supported: true)
        let unsupported = FakeWatchSession(supported: false)
        let container = PersistenceController(inMemory: true).container

        let handler = WatchConnectivityHandler(session: supported, container: container)
        _ = WatchConnectivityHandler(session: unsupported, container: container)

        #expect(supported.activations == 1)
        #expect(supported.delegate === handler)
        #expect(unsupported.activations == 0)
        #expect(unsupported.delegate == nil)
    }
}
