import Testing
import CoreData
import Foundation
@testable import Zeez

/// Counts monitor starts and stops, so a session can start without real audio or Core Motion.
final class FakeSessionMonitors: SessionMonitoring, @unchecked Sendable {
    private let lock = NSLock()
    private var starts = 0
    private var stops = 0
    private let startError: Error?

    /// `startError`: the monitors fail to start with it, as a microphone that won't start does.
    init(startError: Error? = nil) {
        self.startError = startError
    }

    var startCount: Int {
        lock.lock(); defer { lock.unlock() }
        return starts
    }
    var stopCount: Int {
        lock.lock(); defer { lock.unlock() }
        return stops
    }

    func start(for session: SleepSession) throws {
        lock.lock(); starts += 1; lock.unlock()
        if let startError { throw startError }
    }
    func stop() {
        lock.lock(); stops += 1; lock.unlock()
    }
}

/// A recording can start, and always ends (found 2026-10-29).
///
/// `SleepSessionValidator` required readings on a session that had only just been created, so
/// `startSession` failed with `.missingSensorData` every time: no recording had ever started.
/// Ending re-ran the same validator, so a night whose readings stopped early (the app killed or
/// suspended), one under 15 minutes, or one over 24 hours rolled back and stayed active, where
/// `validateOverlap` then blocked every later start.
@Suite("Recording start and end", .serialized) @MainActor
struct RecordingLifecycleTests {

    private func start(_ manager: SleepSessionManager) async -> Result<SleepSession, Error> {
        await withCheckedContinuation { continuation in
            manager.startSession { continuation.resume(returning: $0) }
        }
    }

    private func end(_ manager: SleepSessionManager, _ session: SleepSession,
                     at endTime: Date = Date()) async -> Result<SessionEndOutcome, Error> {
        await withCheckedContinuation { continuation in
            manager.endSession(session, at: endTime) { continuation.resume(returning: $0) }
        }
    }

    /// An active session begun `hoursAgo`, with environmental readings in its first hour only.
    private func runningSession(startedHoursAgo hoursAgo: Double, readingsForFirstHour: Bool,
                                in context: NSManagedObjectContext) throws -> SleepSession {
        let start = Date(timeIntervalSinceNow: -hoursAgo * 3600)
        let session = SleepSession(context: context)
        session.id = UUID()
        session.startTime = start
        session.isActive = true
        if readingsForFirstHour {
            for minute in stride(from: 0, through: 60, by: 5) {
                let reading = EnvironmentalReading(context: context)
                reading.id = UUID()
                reading.timestamp = start.addingTimeInterval(Double(minute) * 60)
                reading.noiseLevel = 40
                reading.session = session
            }
        }
        try context.save()
        return session
    }

    @Test("A recording starts on a fresh store, and starts its monitors once")
    func recordingStarts() async throws {
        let controller = PersistenceController(inMemory: true)
        let monitors = FakeSessionMonitors()
        let manager = SleepSessionManager(persistenceController: controller, monitors: monitors)

        let session = try await start(manager).get()
        #expect(session.isActive)
        #expect(session.startTime != nil)
        #expect(monitors.startCount == 1)
    }

    @Test("A night whose readings stopped early still ends")
    func nightWithAGapEnds() async throws {
        let controller = PersistenceController(inMemory: true)
        let monitors = FakeSessionMonitors()
        let manager = SleepSessionManager(persistenceController: controller, monitors: monitors)
        let session = try runningSession(startedHoursAgo: 8, readingsForFirstHour: true,
                                         in: controller.container.viewContext)

        let outcome = try await end(manager, session).get()
        guard case .saved = outcome else {
            Issue.record("Expected the night to be saved, got \(outcome)")
            return
        }
        #expect(!session.isActive)
        #expect(session.endTime != nil)
        #expect(monitors.stopCount == 1)
    }

    @Test("A night with no readings at all still ends")
    func nightWithoutReadingsEnds() async throws {
        let controller = PersistenceController(inMemory: true)
        let manager = SleepSessionManager(persistenceController: controller, monitors: FakeSessionMonitors())
        let session = try runningSession(startedHoursAgo: 7, readingsForFirstHour: false,
                                         in: controller.container.viewContext)

        let outcome = try await end(manager, session).get()
        guard case .saved = outcome else {
            Issue.record("Expected the night to be saved, got \(outcome)")
            return
        }
        #expect(!session.isActive)
    }

    @Test("A recording under 15 minutes is discarded, not left running")
    func shortRecordingIsDiscarded() async throws {
        let controller = PersistenceController(inMemory: true)
        let monitors = FakeSessionMonitors()
        let manager = SleepSessionManager(persistenceController: controller, monitors: monitors)
        let context = controller.container.viewContext
        let session = try runningSession(startedHoursAgo: 5.0 / 60, readingsForFirstHour: false, in: context)

        let outcome = try await end(manager, session).get()
        guard case .discardedTooShort = outcome else {
            Issue.record("Expected the short recording to be discarded, got \(outcome)")
            return
        }
        let remaining = try context.count(for: SleepSession.fetchRequest())
        #expect(remaining == 0, "A discarded recording must not stay behind, active or not")
        #expect(monitors.stopCount == 1)
    }

    @Test("A recording still running after 24 hours ends at 24 hours")
    func overlongRecordingEndsAtTheMaximum() async throws {
        let controller = PersistenceController(inMemory: true)
        let manager = SleepSessionManager(persistenceController: controller, monitors: FakeSessionMonitors())
        let session = try runningSession(startedHoursAgo: 30, readingsForFirstHour: true,
                                         in: controller.container.viewContext)

        let outcome = try await end(manager, session).get()
        guard case .saved = outcome else {
            Issue.record("Expected the night to be saved, got \(outcome)")
            return
        }
        let start = try #require(session.startTime)
        #expect(session.endTime == start.addingTimeInterval(AppConstants.Sleep.maximumSessionDuration))
    }

    @Test("Once a night with a gap has ended, the next recording can start")
    func nextRecordingStartsAfterAGappedNight() async throws {
        let controller = PersistenceController(inMemory: true)
        let manager = SleepSessionManager(persistenceController: controller, monitors: FakeSessionMonitors())
        let session = try runningSession(startedHoursAgo: 8, readingsForFirstHour: true,
                                         in: controller.container.viewContext)

        _ = try await end(manager, session).get()
        let next = try await start(manager).get()
        #expect(next.isActive)
    }
}
