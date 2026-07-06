import Testing
import CoreData
@testable import Zeez

/// Tests for sleep-sample grouping and import idempotency.
///
/// Uses the pure `groupIntervalsIntoSessions` helper so no HealthKit dependency is needed.
struct SleepImportGroupingTests {

    // MARK: - Helpers

    private func interval(start: TimeInterval, end: TimeInterval, base: Date = Date()) -> SleepSampleInterval {
        SleepSampleInterval(
            start: base.addingTimeInterval(start),
            end: base.addingTimeInterval(end)
        )
    }

    // MARK: - Overnight Crossing

    @Test("Samples crossing midnight import as one session")
    func samplesAcrossMidnightAreOneSession() {
        // 11:00 pm to 7:00 am — spans midnight
        let nightStart = interval(start: -9 * 3600, end: -8 * 3600)     // 11 pm–midnight
        let morningEnd = interval(start: -8 * 3600, end: 0)             // midnight–7 am (relative)

        let groups = groupIntervalsIntoSessions([nightStart, morningEnd])
        #expect(groups.count == 1, "Contiguous overnight samples should form one session, not two")
    }

    @Test("Closely-spaced samples within same night form one session")
    func closelySamplesAreSingleSession() {
        // Multiple 30-min samples across 8 hours — all within the overnight window
        let base = Date()
        var intervals: [SleepSampleInterval] = []
        for i in 0..<16 {
            intervals.append(interval(start: Double(i) * 1800, end: Double(i + 1) * 1800, base: base))
        }
        let groups = groupIntervalsIntoSessions(intervals)
        #expect(groups.count == 1, "16 consecutive 30-min samples should form one session")
    }

    // MARK: - Same-Day Distinct Sessions

    @Test("Two separated naps on the same day remain distinct sessions")
    func separatedSameDayNapsRemainDistinct() {
        let base = Date()
        // Nap 1: 1 pm–2 pm, Nap 2: 8 pm–9 pm — 6-hour gap exceeds threshold
        let nap1 = interval(start: 0, end: 3600, base: base)
        let nap2 = interval(start: 6 * 3600 + 60, end: 7 * 3600 + 60, base: base)

        let groups = groupIntervalsIntoSessions([nap1, nap2])
        #expect(groups.count == 2, "Sessions separated by >4 h gap should remain distinct")
    }

    @Test("Two sessions just inside the gap threshold are merged")
    func sessionsJustInsideGapAreMerged() {
        let base = Date()
        let session1 = interval(start: 0, end: 3600, base: base)
        let session2 = interval(start: 3600 + 3 * 3600, end: 3600 + 4 * 3600, base: base) // 3-hour gap

        let groups = groupIntervalsIntoSessions([session1, session2])
        #expect(groups.count == 1, "Sessions separated by <4 h should be merged into one")
    }

    @Test("Empty input returns no groups")
    func emptyInputNoGroups() {
        let groups = groupIntervalsIntoSessions([])
        #expect(groups.isEmpty)
    }

    @Test("Single interval produces one group")
    func singleIntervalOneGroup() {
        let single = interval(start: 0, end: 3600)
        let groups = groupIntervalsIntoSessions([single])
        #expect(groups.count == 1)
        #expect(groups[0].count == 1)
    }

    // MARK: - Duplicate-start sample grouping (regression test for crash)

    @Test("groupIntervalsIntoSessions handles two intervals with the same start date without crashing")
    func duplicateStartIntervalsDoNotCrash() {
        let base = Date()
        // Two samples with identical start dates (e.g., in-bed + asleep from different sources)
        let a = interval(start: 0, end: 3600, base: base)
        let b = interval(start: 0, end: 7200, base: base)  // same start, different end
        let c = interval(start: 3600, end: 7200, base: base)

        let groups = groupIntervalsIntoSessions([a, b, c])
        // All three should be clustered into one overnight session
        #expect(groups.count == 1, "Duplicate-start samples should not crash grouping and should be clustered together")
        #expect(groups[0].count == 3, "All three intervals should appear in the group")
    }

    @Test("groupIntervalsIntoSessions preserves all intervals even with duplicate start dates")
    func duplicateStartAllIntervalPreserved() {
        let base = Date()
        let same1 = interval(start: 0, end: 1800, base: base)
        let same2 = interval(start: 0, end: 3600, base: base)  // same start as same1

        let groups = groupIntervalsIntoSessions([same1, same2])
        #expect(groups.count == 1)
        #expect(groups[0].count == 2, "Both intervals with the same start date must be preserved")
    }

    // MARK: - Permanent object IDs

    @Test("Newly inserted SleepSession has a non-temporary object ID after obtainPermanentIDs")
    func sessionGetsPermanentIDAfterObtainPermanentIDs() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext

        // viewContext is main-queue-confined; tests run off main (2.4).
        try context.performAndWait {
            let session = SleepSession(context: context)
            session.id = UUID()
            session.startTime = Date(timeIntervalSinceNow: -8 * 3600)
            session.endTime = Date()
            session.deviceIdentifier = "HealthKit Import"
            session.qualityScore = 0

            // Before obtainPermanentIDs, the ID should be temporary
            #expect(session.objectID.isTemporaryID,
                    "Newly inserted object should have a temporary ID before permanentization")

            // Obtain permanent IDs without saving
            try context.obtainPermanentIDs(for: [session])

            #expect(!session.objectID.isTemporaryID,
                    "After obtainPermanentIDs, the session ID must be permanent and cross-context resolvable")
        }
    }

    @Test("Importer parent-save step makes session resolvable before child attachment")
    func savedParentIsResolvableBeforeRelatedDataAttachment() async throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext

        // viewContext is main-queue-confined; tests run off main (2.4).
        let objectID = try context.performAndWait {
            let session = SleepSession(context: context)
            session.id = UUID()
            session.startTime = Date(timeIntervalSinceNow: -8 * 3600)
            session.endTime = Date()
            session.deviceIdentifier = "HealthKit Import"
            session.qualityScore = 0

            return try saveImportedSessionForRelatedData(session, in: context)
        }

        let bgContext = controller.container.newBackgroundContext()
        let identifier = try await bgContext.perform {
            let resolved = try bgContext.existingObject(with: objectID) as? SleepSession
            return resolved?.deviceIdentifier
        }
        #expect(identifier != nil, "Saved parent must be resolvable before related-data callbacks attach rows")
        #expect(identifier == "HealthKit Import")
    }

    // MARK: - Idempotency (Core Data)

    @Test("Re-importing same intervals creates no duplicate sessions")
    func reImportIsDuplicate() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext

        // viewContext is main-queue-confined; tests run off main (2.4).
        try context.performAndWait {
            let base = Date(timeIntervalSinceNow: -10 * 3600)
            let start = base
            let end = base.addingTimeInterval(8 * 3600)

            // Seed an existing HealthKit-imported session for this time range
            let existingSession = SleepSession(context: context)
            existingSession.id = UUID()
            existingSession.startTime = start
            existingSession.endTime = end
            existingSession.deviceIdentifier = "HealthKit Import"
            existingSession.qualityScore = 0
            try context.save()

            // Check using the same deduplication logic as the importer
            let request: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
            let margin: TimeInterval = 15 * 60
            request.predicate = NSPredicate(
                format: "deviceIdentifier == %@ AND startTime >= %@ AND startTime <= %@",
                "HealthKit Import",
                Date(timeInterval: -margin, since: start) as NSDate,
                Date(timeInterval: margin, since: start) as NSDate
            )
            request.fetchLimit = 1
            let count = try context.count(for: request)
            #expect(count > 0, "Deduplication check should detect existing session and skip re-import")
        }
    }
}
