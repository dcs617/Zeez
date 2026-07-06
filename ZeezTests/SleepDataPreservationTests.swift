import Testing
import CoreData
@testable import Zeez

/// Regression tests ensuring mock data generation/cleanup never deletes real imported records.
struct SleepDataPreservationTests {

    // MARK: - Helpers

    /// Runs `body` on the viewContext's own queue with the controller kept
    /// alive. The viewContext is main-queue-confined and Swift Testing runs
    /// tests off the main thread — unguarded access raced the main runloop
    /// and crashed the runner inside MockDataGenerator (2.4).
    private func withInMemoryContext(_ body: (NSManagedObjectContext) throws -> Void) throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        try context.performAndWait {
            try body(context)
        }
    }

    private func makeRealSession(in context: NSManagedObjectContext, deviceIdentifier: String = "HealthKit Import") -> SleepSession {
        let session = SleepSession(context: context)
        session.id = UUID()
        session.startTime = Date(timeIntervalSinceNow: -8 * 3600)
        session.endTime = Date()
        session.deviceIdentifier = deviceIdentifier
        session.qualityScore = 75.0
        session.isActive = false
        return session
    }

    private func makeMockSession(in context: NSManagedObjectContext) -> SleepSession {
        let session = SleepSession(context: context)
        session.id = UUID()
        session.startTime = Date(timeIntervalSinceNow: -32 * 3600)
        session.endTime = Date(timeIntervalSinceNow: -24 * 3600)
        session.deviceIdentifier = "Mock Data - iPhone"
        session.qualityScore = 80.0
        session.isActive = false
        return session
    }

    // MARK: - Tests

    @Test("clearMockData preserves real HealthKit session")
    func clearMockDataPreservesHealthKitSession() throws {
        try withInMemoryContext { context in
            let realSession = makeRealSession(in: context)
            let mockSession = makeMockSession(in: context)

            let realStage = SleepStage(context: context)
            realStage.id = UUID()
            realStage.stageType = "deep"
            realStage.session = realSession

            let mockStage = SleepStage(context: context)
            mockStage.id = UUID()
            mockStage.stageType = "light"
            mockStage.session = mockSession

            try context.save()

            // Run mock cleanup using the test context
            let generator = MockDataGenerator(context: context)
            generator.clearMockData()

            // Real session must survive
            let sessionRequest: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
            sessionRequest.predicate = NSPredicate(format: "deviceIdentifier == %@", "HealthKit Import")
            let survivors = try context.fetch(sessionRequest)
            #expect(survivors.count == 1, "Real HealthKit session must survive mock cleanup")

            // Real session's child stage must survive
            let stageRequest: NSFetchRequest<SleepStage> = SleepStage.fetchRequest()
            stageRequest.predicate = NSPredicate(format: "session.deviceIdentifier == %@", "HealthKit Import")
            let survivingStages = try context.fetch(stageRequest)
            #expect(survivingStages.count == 1, "Real session's sleep stages must survive mock cleanup")
        }
    }

    @Test("clearMockData removes all mock sessions and their stages")
    func clearMockDataRemovesMockData() throws {
        try withInMemoryContext { context in
            let real = makeRealSession(in: context)
            _ = real // ensure retained

            for _ in 0..<3 {
                let mock = makeMockSession(in: context)
                let stage = SleepStage(context: context)
                stage.id = UUID()
                stage.stageType = "rem"
                stage.session = mock
            }
            try context.save()

            let generator = MockDataGenerator(context: context)
            generator.clearMockData()

            let mockRequest: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
            mockRequest.predicate = NSPredicate(format: "deviceIdentifier CONTAINS[c] %@", "Mock Data")
            let remaining = try context.fetch(mockRequest)
            #expect(remaining.isEmpty, "All mock sessions should be removed")
        }
    }

    @Test("generateMockData preserves real HealthKit session")
    func generateMockDataPreservesRealSession() throws {
        try withInMemoryContext { context in
            let realSession = makeRealSession(in: context)
            let realStage = SleepStage(context: context)
            realStage.id = UUID()
            realStage.stageType = "deep"
            realStage.session = realSession
            try context.save()

            // Generate mock data (which internally calls clearMockData)
            MockDataGenerator(context: context).generateMockData(for: 3)

            let request: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
            request.predicate = NSPredicate(format: "deviceIdentifier == %@", "HealthKit Import")
            let survivors = try context.fetch(request)
            #expect(survivors.count == 1, "Real HealthKit session must survive generateMockData")
        }
    }

    @Test("clearMockData is source-aware across multiple real origins")
    func clearMockDataPreservesMultipleRealOrigins() throws {
        try withInMemoryContext { context in
            // Real sessions from different non-mock sources
            _ = makeRealSession(in: context, deviceIdentifier: "HealthKit Import")
            _ = makeRealSession(in: context, deviceIdentifier: "Pillow Import")
            _ = makeRealSession(in: context, deviceIdentifier: "Manual Entry")
            _ = makeMockSession(in: context)
            try context.save()

            MockDataGenerator(context: context).clearMockData()

            let allRequest: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
            let all = try context.fetch(allRequest)
            #expect(all.count == 3, "All three real-origin sessions should survive")

            let mockRequest: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
            mockRequest.predicate = NSPredicate(format: "deviceIdentifier CONTAINS[c] %@", "Mock Data")
            let mocks = try context.fetch(mockRequest)
            #expect(mocks.isEmpty, "Mock session should be gone")
        }
    }
}
