import Testing
import CoreData
import Foundation
@testable import Zeez

/// Heart rate from Apple Health, answered at once or held until the test releases it.
final class FakeHeartRateSource: HeartRateSource, @unchecked Sendable {
    typealias Samples = [(timestamp: Date, value: Double)]

    private let lock = NSLock()
    private let holds: Bool
    private var requested: [ClosedRange<Date>] = []
    private var held: [(Result<Samples, Error>) -> Void] = []

    init(holds: Bool = false) {
        self.holds = holds
    }

    var requests: [ClosedRange<Date>] {
        lock.lock(); defer { lock.unlock() }
        return requested
    }

    func heartRates(from start: Date, to end: Date, completion: @escaping (Result<Samples, Error>) -> Void) {
        lock.lock()
        requested.append(start...end)
        if holds { held.append(completion) }
        lock.unlock()
        if !holds { completion(.success(Self.samples(from: start))) }
    }

    /// Answers every held request.
    func release() {
        lock.lock()
        let pending = held
        let ranges = requested
        held = []
        lock.unlock()
        for (completion, range) in zip(pending, ranges) {
            completion(.success(Self.samples(from: range.lowerBound)))
        }
    }

    /// One reading every ten minutes for the first hour: six after downsampling.
    static func samples(from start: Date) -> Samples {
        (0..<6).map { (timestamp: start.addingTimeInterval(Double($0) * 600 + 60), value: 58) }
    }
}

/// What happens to a night the app could not finish (2026-11-01).
///
/// Before: a recording the app was closed during stayed active forever and blocked every
/// later start; a recording that ended with the phone locked never got its heart rate; and a
/// recording of 15–30 minutes, kept since 2026-10-29, made the analyzer throw, which ended
/// every background backlog run before it reached an older night.
@Suite("Recovering an unfinished night", .serialized) @MainActor
struct RecordingRecoveryTests {

    private func controller(_ persistence: PersistenceController, errors: ErrorManager,
                            heartRates: HeartRateSource = FakeHeartRateSource()) -> SleepRecordingController {
        SleepRecordingController(
            manager: SleepSessionManager(persistenceController: persistence, monitors: FakeSessionMonitors(),
                                         heartRateSource: heartRates),
            notificationCenter: FakeNotificationCenter(),
            microphone: FakeMicrophonePermission(granted: true),
            errors: errors)
    }

    /// A session left active, as a killed app leaves it, with noise samples every five minutes.
    private func orphan(startingHoursAgo hours: Double, samples: Int, in context: NSManagedObjectContext) throws -> SleepSession {
        let start = Date().addingTimeInterval(-hours * 3600)
        let session = SleepSession(context: context)
        session.id = UUID()
        session.startTime = start
        session.isActive = true
        for index in 0..<samples {
            let reading = EnvironmentalReading(context: context)
            reading.id = UUID()
            reading.timestamp = start.addingTimeInterval(Double(index + 1) * 300)
            reading.noiseLevel = 60
            reading.session = session
        }
        try context.save()
        return session
    }

    private func ended(_ persistence: PersistenceController, hoursAgo: Double, length: Double,
                       deviceIdentifier: String = "recorded-phone") throws -> SleepSession {
        let context = persistence.container.viewContext
        let end = Date().addingTimeInterval(-hoursAgo * 3600)
        let session = SleepSession(context: context)
        session.id = UUID()
        session.startTime = end.addingTimeInterval(-length * 3600)
        session.endTime = end
        session.isActive = false
        session.deviceIdentifier = deviceIdentifier
        try context.save()
        return session
    }

    private func heartRateCount(_ session: SleepSession) -> Int {
        session.managedObjectContext?.refresh(session, mergeChanges: true)
        return session.heartRateData?.count ?? 0
    }

    // MARK: Interrupted recording

    @Test("A recording the app was closed during ends at its last sample, and the alert says so")
    func orphanEndsAtItsLastSample() async throws {
        let persistence = PersistenceController(inMemory: true)
        let errors = ErrorManager()
        let session = try orphan(startingHoursAgo: 6, samples: 36, in: persistence.container.viewContext)
        let lastSample = try #require(session.startTime).addingTimeInterval(36 * 300)

        await withCheckedContinuation { continuation in
            controller(persistence, errors: errors).recoverInterruptedRecording { continuation.resume() }
        }

        #expect(!session.isActive, "Left active, it blocks every later recording")
        #expect(session.endTime == lastSample, "Not the moment Zeez was reopened: nothing was recorded after this")
        #expect(errors.currentAlert == .recordingEndedEarly(savedUntil: lastSample))
    }

    @Test("One cut off before it was long enough to keep is discarded without an alert")
    func shortOrphanIsDiscardedQuietly() async throws {
        let persistence = PersistenceController(inMemory: true)
        let errors = ErrorManager()
        _ = try orphan(startingHoursAgo: 6, samples: 1, in: persistence.container.viewContext)

        await withCheckedContinuation { continuation in
            controller(persistence, errors: errors).recoverInterruptedRecording { continuation.resume() }
        }

        #expect(try persistence.container.viewContext.count(for: SleepSession.fetchRequest()) == 0)
        #expect(errors.currentAlert == nil)
    }

    @Test("A recording running in this process is not taken for an interrupted one")
    func liveRecordingIsLeftAlone() async throws {
        let persistence = PersistenceController(inMemory: true)
        let errors = ErrorManager()
        let recording = controller(persistence, errors: errors)
        let session: SleepSession = try await withCheckedThrowingContinuation { continuation in
            recording.start { continuation.resume(with: $0) }
        }

        await withCheckedContinuation { continuation in
            recording.recoverInterruptedRecording { continuation.resume() }
        }

        #expect(session.isActive)
        #expect(recording.activeSession == session)
    }

    @Test("The app ends an interrupted recording at launch")
    func launchRecovers() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Zeez/App/ZeezApp.swift")
        #expect(try String(contentsOf: url, encoding: .utf8).contains("SleepRecordingController.shared.recoverInterruptedRecording()"))
    }

    // MARK: Heart rate

    @Test("Back in the foreground, a recent recording that ended without heart rate gets it")
    func foregroundSyncsPendingHeartRate() async throws {
        let persistence = PersistenceController(inMemory: true)
        let source = FakeHeartRateSource()
        let pending = try ended(persistence, hoursAgo: 1, length: 7)
        let old = try ended(persistence, hoursAgo: 48, length: 7)
        let imported = try ended(persistence, hoursAgo: 1, length: 7,
                                 deviceIdentifier: "Apple Watch \(AppConstants.DataProvenance.healthKitMarker)")

        controller(persistence, errors: ErrorManager(), heartRates: source).appBecameActive()
        try await AlarmTestSupport.waitUntil("the heart rate") { heartRateCount(pending) > 0 }

        #expect(heartRateCount(pending) == FakeHeartRateSource.samples(from: Date()).count)
        let asked = source.requests.map(\.lowerBound)
        #expect(asked == [try #require(pending.startTime)], "Only the recent recording without heart rate is looked up")
        #expect(heartRateCount(old) == 0)
        #expect(heartRateCount(imported) == 0)
    }

    @Test("Two syncs of one night insert its heart rate once")
    func concurrentSyncsInsertOnce() async throws {
        let persistence = PersistenceController(inMemory: true)
        let source = FakeHeartRateSource(holds: true)
        let manager = SleepSessionManager(persistenceController: persistence, monitors: FakeSessionMonitors(),
                                          heartRateSource: source)
        let session = try ended(persistence, hoursAgo: 1, length: 7)

        // The end-of-recording sync is still waiting for Apple Health when Zeez comes back
        // to the foreground and looks for nights without heart rate.
        manager.syncWithHealthKit(for: session) { _ in }
        manager.syncPendingHeartRate()
        #expect(source.requests.count == 1)

        source.release()
        try await AlarmTestSupport.waitUntil("the heart rate") { heartRateCount(session) > 0 }
        #expect(heartRateCount(session) == FakeHeartRateSource.samples(from: Date()).count)
    }

    // MARK: Analysis backlog

    @Test("A night too short to analyze gets the no-score marker instead of an error")
    func shortNightGetsTheSentinel() async throws {
        let persistence = PersistenceController(inMemory: true)
        let session = try ended(persistence, hoursAgo: 1, length: 0.4)

        try await SleepAnalyzer.shared.analyzeSleepSession(objectID: session.objectID, container: persistence.container)

        persistence.container.viewContext.refresh(session, mergeChanges: true)
        #expect(session.qualityScore == 1.0, "Left at 0, the backlog retries it on every run")
    }

    @Test("One night that cannot be analyzed does not stop the backlog reaching older ones")
    func backlogSkipsAFailure() async throws {
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.container.viewContext
        let broken = try ended(persistence, hoursAgo: 1, length: 7)
        let older = try ended(persistence, hoursAgo: 30, length: 7)
        let brokenID = broken.objectID

        let analyzed = try await BackgroundTaskManager.analyzeBacklog(
            in: persistence.container.newBackgroundContext(),
            batchSize: 10,
            canContinue: { true },
            analyze: { objectID in
                if objectID == brokenID { throw AnalysisError.noDataAvailable }
                try await SleepAnalyzer.shared.analyzeSleepSession(objectID: objectID, container: persistence.container)
            })

        // Analyzed: without inputs it gets the no-score marker. Unreached, it stays at 0.
        context.refresh(older, mergeChanges: true)
        #expect(analyzed == 1)
        #expect(older.qualityScore == 1.0, "The older night was never reached")
    }
}
