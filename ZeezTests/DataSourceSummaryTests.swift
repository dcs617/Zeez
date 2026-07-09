import Testing
import CoreData
import Foundation
@testable import Zeez

/// Covers `RealDataManager.getDataSources()` after the C6 rewrite, which replaced three
/// full object fetches with `count(for:)` plus a one-row `createdAt` fetch.
///
/// The interesting claim is the ordering one: the last-import date comes from a descending
/// sort on `createdAt` with `fetchLimit = 1`, which is only correct because SQLite orders
/// NULL below every value, so a session with no `createdAt` lands last rather than first.
/// That is not obvious from reading the code, so it is pinned here.
@Suite("Data source summary (C6)")
struct DataSourceSummaryTests {

    private func makeSession(in context: NSManagedObjectContext,
                             device: String?,
                             createdAt: Date?) {
        context.performAndWait {
            let session = SleepSession(context: context)
            session.id = UUID()
            session.deviceIdentifier = device
            session.createdAt = createdAt
            session.startTime = Date(timeIntervalSinceReferenceDate: 800_000_000)
            session.endTime = Date(timeIntervalSinceReferenceDate: 800_028_800)
            session.isActive = false
        }
        try? context.save()
    }

    private func makeManager() -> (RealDataManager, NSManagedObjectContext) {
        let controller = PersistenceController(inMemory: true)
        return (RealDataManager(persistenceController: controller),
                controller.container.viewContext)
    }

    @Test("An empty store reports zero sessions and no import date")
    func emptyStoreSummarizesToZero() {
        let (manager, _) = makeManager()
        let sources = manager.getDataSources()

        for source in [SleepDataSource.healthKit, .manual, .mock] {
            #expect(sources[source]?.count == 0)
            #expect(sources[source]?.lastImport == nil)
        }
    }

    @Test("Each provenance bucket counts only its own sessions")
    func bucketsCountTheirOwnSessions() throws {
        let (manager, context) = makeManager()
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

        makeSession(in: context, device: "HealthKit", createdAt: now)
        makeSession(in: context, device: "HealthKit", createdAt: now)
        makeSession(in: context, device: "Mock Data", createdAt: now)
        makeSession(in: context, device: "iPhone", createdAt: now)   // legacy mock marker
        makeSession(in: context, device: nil, createdAt: now)        // nil device reads as mock

        let sources = manager.getDataSources()

        #expect(sources[.healthKit]?.count == 2)
        // Mock = the "Mock Data" marker, the legacy "iPhone" device, and nil identifiers.
        #expect(sources[.mock]?.count == 3)
        // Manual means "not mock", so HealthKit sessions are real data and count here too.
        // The legacy "iPhone" session must NOT appear here: it is mock data, and
        // `clearMockData` deletes it as such.
        #expect(sources[.manual]?.count == 2)

        // The two buckets are complements, so together they account for every session.
        let manual = try #require(sources[.manual]?.count)
        let mock = try #require(sources[.mock]?.count)
        #expect(manual + mock == 5, "mock and non-mock must partition the store, never overlap")
    }

    @Test("A store holding only legacy mock sessions is not 'real data'")
    func legacyMockSessionsAreNotRealData() {
        let (manager, context) = makeManager()
        // Early mock builds wrote a bare "iPhone" device identifier. `clearMockData` still
        // deletes these, so `hasRealData` must not call them real — Settings would otherwise
        // show "Using your real sleep data" above fabricated sessions.
        makeSession(in: context, device: "iPhone", createdAt: Date())
        makeSession(in: context, device: "Mock Data - iPhone", createdAt: Date())

        #expect(manager.hasRealData() == false)
    }

    @Test("A real HealthKit session makes the store 'real data'")
    func healthKitSessionsAreRealData() {
        let (manager, context) = makeManager()
        makeSession(in: context, device: "HealthKit Import", createdAt: Date())

        #expect(manager.hasRealData() == true)
    }

    @Test("Last import is the newest createdAt, not the first row encountered")
    func lastImportIsTheNewestDate() throws {
        let (manager, context) = makeManager()
        let oldest = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let newest = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let middle = Date(timeIntervalSinceReferenceDate: 750_000_000)

        // Inserted out of order, so a fetch that ignored the sort would pick the wrong one.
        makeSession(in: context, device: "HealthKit", createdAt: middle)
        makeSession(in: context, device: "HealthKit", createdAt: newest)
        makeSession(in: context, device: "HealthKit", createdAt: oldest)

        let lastImport = try #require(manager.getDataSources()[.healthKit]?.lastImport)
        #expect(abs(lastImport.timeIntervalSince(newest)) < 0.001)
    }

    @Test("A session with no createdAt never masks a real import date")
    func nilCreatedAtSortsLast() throws {
        let (manager, context) = makeManager()
        let real = Date(timeIntervalSinceReferenceDate: 800_000_000)

        // `fetchLimit = 1` on a descending sort only returns the real date because SQLite
        // orders NULL below every value. Insert the nil first so a naive fetch would take it.
        makeSession(in: context, device: "HealthKit", createdAt: nil)
        makeSession(in: context, device: "HealthKit", createdAt: real)

        let summary = try #require(manager.getDataSources()[.healthKit])
        #expect(summary.count == 2, "The nil-createdAt session is still counted")
        let lastImport = try #require(summary.lastImport, "A nil createdAt must not shadow a real date")
        #expect(abs(lastImport.timeIntervalSince(real)) < 0.001)
    }

    @Test("A bucket whose sessions all lack createdAt reports no import date")
    func allNilCreatedAtReportsNoDate() {
        let (manager, context) = makeManager()
        makeSession(in: context, device: "HealthKit", createdAt: nil)

        let summary = manager.getDataSources()[.healthKit]
        #expect(summary?.count == 1)
        #expect(summary?.lastImport == nil)
    }
}
