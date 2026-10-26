import CoreData
import Foundation
import Testing
@testable import Zeez

/// Heart-rate and respiratory readings for an imported night are replaced, not appended, so a
/// re-import that refreshes a changed night does not double them (PARKED_CAPABILITIES §8a).
struct ImportedRelatedDataTests {

    private let night = Date(timeIntervalSince1970: 1_790_895_600)

    private func makeSession(in controller: PersistenceController) throws -> NSManagedObjectID {
        let context = controller.newBackgroundContext()
        return try context.performAndWait {
            let session = SleepSession(context: context)
            session.id = UUID()
            session.startTime = night
            session.endTime = night.addingTimeInterval(8 * 3600)
            session.deviceIdentifier = AppConstants.DataProvenance.healthKitImport
            try context.save()
            return session.objectID
        }
    }

    private func heartRate(_ count: Int) -> [HeartRateDownsampler.Reading] {
        (0..<count).map {
            HeartRateDownsampler.Reading(timestamp: night.addingTimeInterval(Double($0) * 60),
                                         value: 55, sampleCount: 1, deviceType: "Apple Watch")
        }
    }

    private func respiratory(_ count: Int) -> [ImportedRespiratoryReading] {
        (0..<count).map {
            ImportedRespiratoryReading(timestamp: night.addingTimeInterval(Double($0) * 600),
                                       rate: 14, deviceType: "Apple Watch")
        }
    }

    private func counts(for sessionID: NSManagedObjectID,
                        in controller: PersistenceController) throws -> (heartRate: Int, respiratory: Int) {
        let context = controller.newBackgroundContext()
        // A private context's performAndWait would keep this test's issues, but the
        // attribution guard cannot tell it from the viewContext, so require outside it.
        let counts = try context.performAndWait { () -> (heartRate: Int, respiratory: Int)? in
            guard let session = try context.existingObject(with: sessionID) as? SleepSession else { return nil }
            return (session.heartRateData?.count ?? 0, session.respiratoryData?.count ?? 0)
        }
        return try #require(counts)
    }

    private func store(heartRate: [HeartRateDownsampler.Reading] = [],
                       respiratory: [ImportedRespiratoryReading] = [],
                       for sessionID: NSManagedObjectID,
                       in controller: PersistenceController) throws {
        let context = controller.newBackgroundContext()
        try context.performAndWait {
            try storeHeartRateReadings(heartRate, forSessionID: sessionID, in: context)
            try storeRespiratoryReadings(respiratory, forSessionID: sessionID, in: context)
        }
    }

    @Test("Re-storing a night's readings replaces them")
    func restoringReplaces() throws {
        let controller = PersistenceController(inMemory: true)
        let sessionID = try makeSession(in: controller)

        try store(heartRate: heartRate(3), respiratory: respiratory(2), for: sessionID, in: controller)
        try store(heartRate: heartRate(5), respiratory: respiratory(4), for: sessionID, in: controller)

        let stored = try counts(for: sessionID, in: controller)
        #expect(stored.heartRate == 5, "Appending would leave 8 heart-rate readings")
        #expect(stored.respiratory == 4, "Appending would leave 6 respiratory readings")
    }

    @Test("An empty fetch keeps the stored readings")
    func emptyFetchKeepsReadings() throws {
        let controller = PersistenceController(inMemory: true)
        let sessionID = try makeSession(in: controller)
        try store(heartRate: heartRate(3), respiratory: respiratory(2), for: sessionID, in: controller)

        // What HealthKit returns once read access is revoked.
        try store(for: sessionID, in: controller)

        let stored = try counts(for: sessionID, in: controller)
        #expect(stored.heartRate == 3)
        #expect(stored.respiratory == 2)
    }

    @Test("A session that no longer exists is an error, not a silent no-op")
    func missingSessionThrows() throws {
        let controller = PersistenceController(inMemory: true)
        let sessionID = try makeSession(in: controller)
        let context = controller.newBackgroundContext()
        try context.performAndWait {
            context.delete(try context.existingObject(with: sessionID))
            try context.save()
        }

        #expect(throws: (any Error).self) {
            try context.performAndWait {
                try storeHeartRateReadings(heartRate(1), forSessionID: sessionID, in: context)
            }
        }
    }
}
