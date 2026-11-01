import Testing
import CoreData
import Foundation
@testable import Zeez

final class FakeMicrophonePermission: MicrophonePermission, @unchecked Sendable {
    private let lock = NSLock()
    private let granted: Bool
    private var requests = 0

    init(granted: Bool) {
        self.granted = granted
    }

    var isGranted: Bool { granted }

    var requestCount: Int {
        lock.lock(); defer { lock.unlock() }
        return requests
    }

    func request(_ completion: @escaping (Bool) -> Void) {
        lock.lock(); requests += 1; lock.unlock()
        completion(granted)
    }
}

/// A recording needs the microphone (decision 2026-11-01).
///
/// Before, Start created the session whatever the answer, and a refused microphone left a
/// recording running that measured nothing, and could not keep the app running overnight.
/// Now Start asks first, and when the microphone is refused or will not start, no session is
/// left behind and the alert says why, with Open Settings for the refusal.
@Suite("A recording needs the microphone", .serialized) @MainActor
struct RecordingMicrophoneTests {

    private struct Fixture {
        let persistence = PersistenceController(inMemory: true)
        let errors = ErrorManager()
        let monitors: FakeSessionMonitors
        let microphone: FakeMicrophonePermission
        let controller: SleepRecordingController

        init(granted: Bool, monitorError: Error? = nil) {
            monitors = FakeSessionMonitors(startError: monitorError)
            microphone = FakeMicrophonePermission(granted: granted)
            controller = SleepRecordingController(
                manager: SleepSessionManager(persistenceController: persistence, monitors: monitors),
                notificationCenter: FakeNotificationCenter(),
                microphone: microphone,
                errors: errors)
        }

        func start() async -> Result<SleepSession, Error> {
            await withCheckedContinuation { continuation in
                controller.start { continuation.resume(returning: $0) }
            }
        }

        func sessionCount() throws -> Int {
            try persistence.container.viewContext.count(for: SleepSession.fetchRequest())
        }
    }

    @Test("Without microphone access Start records nothing, and the alert offers Settings")
    func refusedMicrophoneStartsNothing() async throws {
        let fixture = Fixture(granted: false)

        let result = await fixture.start()

        guard case .failure(let error) = result else {
            Issue.record("A recording started without the microphone")
            return
        }
        #expect((error as? AppError) == .microphonePermissionDenied)
        #expect(fixture.microphone.requestCount == 1)
        #expect(try fixture.sessionCount() == 0)
        #expect(fixture.monitors.startCount == 0)
        #expect(fixture.controller.activeSession == nil)
        #expect(fixture.errors.currentAlert == .microphonePermissionDenied)
        #expect(fixture.errors.currentAlert?.opensSettings == true)
    }

    @Test("Each refused Start says why, not only the first")
    func everyRefusedStartAlerts() async {
        let fixture = Fixture(granted: false)

        _ = await fixture.start()
        #expect(fixture.errors.currentAlert == .microphonePermissionDenied)
        fixture.errors.dismissAlert()

        _ = await fixture.start()
        #expect(fixture.errors.currentAlert == .microphonePermissionDenied,
                "A second tap on Start did nothing visible")
    }

    @Test("A recording whose microphone will not start is not left running")
    func monitorFailureLeavesNoSession() async throws {
        let fixture = Fixture(granted: true, monitorError: AppError.sensorDataUnavailable)

        let result = await fixture.start()

        guard case .failure = result else {
            Issue.record("Start reported success with no microphone running")
            return
        }
        #expect(try fixture.sessionCount() == 0, "The session stays active and blocks every later Start")
        #expect(fixture.monitors.stopCount == 1)
        #expect(fixture.controller.activeSession == nil)
        #expect(fixture.errors.currentAlert == .sleepSessionCreationFailed)
    }

    @Test("With microphone access the recording starts, with no alert")
    func grantedMicrophoneStarts() async throws {
        let fixture = Fixture(granted: true)

        let session = try await fixture.start().get()

        #expect(session.isActive)
        #expect(fixture.controller.activeSession == session)
        #expect(fixture.monitors.startCount == 1)
        #expect(try fixture.sessionCount() == 1)
        #expect(fixture.errors.currentAlert == nil)
    }
}
