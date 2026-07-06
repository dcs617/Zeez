import Testing
import CoreData
import Foundation
@testable import Zeez

/// Regression tests for the alarm-ID predicate fix (roadmap items 0.2/0.3).
///
/// `AlarmConfiguration.id` is a UUID attribute. SQLite stores cannot evaluate a
/// `"id.uuidString == %@"` keypath predicate — the fetch raises an ObjC
/// `NSInvalidArgumentException` at runtime that a Swift `catch` does not reliably
/// intercept. The in-memory stores used by the other alarm suites evaluate that
/// keypath happily and mask the bug, so this suite runs against a real SQLite
/// store at a temp URL and executes the exact predicate shape production now
/// uses (parse the string to a UUID, compare the attribute directly).
///
/// Note: a companion test asserting the OLD `"id.uuidString == %@"` form fails is
/// intentionally omitted — on a SQLite store it traps via an ObjC exception that
/// Swift Testing cannot catch, which would crash the test runner rather than
/// record a failure.
struct AlarmPredicateSQLiteTests {

    // MARK: - Harness

    /// Loads the Zeez model into a SQLite store at a unique temp URL, runs the
    /// test body, then destroys the store and removes its files.
    private func withSQLiteStore(_ body: (NSPersistentContainer) async throws -> Void) async throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AlarmPredicateSQLiteTests-\(UUID().uuidString).sqlite")

        let container = NSPersistentContainer(name: "Zeez")
        let description = NSPersistentStoreDescription(url: storeURL)
        description.type = NSSQLiteStoreType
        container.persistentStoreDescriptions = [description]

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            container.loadPersistentStores { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }

        defer {
            try? container.persistentStoreCoordinator.destroyPersistentStore(
                at: storeURL, ofType: NSSQLiteStoreType, options: nil
            )
            for suffix in ["", "-wal", "-shm"] {
                try? FileManager.default.removeItem(atPath: storeURL.path + suffix)
            }
        }

        try await body(container)
    }

    private func insertAlarm(id: UUID, into container: NSPersistentContainer) async throws {
        let context = container.newBackgroundContext()
        try await context.perform {
            let alarm = AlarmConfiguration(context: context)
            alarm.id = id
            alarm.name = "Predicate Test Alarm"
            alarm.enabled = true
            alarm.alarmSound = "Alarm_Honk.caf"
            alarm.vibrationOnly = false
            alarm.watchHaptics = true
            alarm.setValue(true, forKey: "heavySleeperMode")
            try context.save()
        }
    }

    /// The production predicate shape: parse the incoming string ID to a UUID,
    /// compare the attribute directly. Mirrors AlarmNotificationUtils.scheduleSnooze
    /// and the three AlarmNotificationHandler lookups.
    private func fetchAlarm(alarmId: String, in context: NSManagedObjectContext) throws -> AlarmConfiguration? {
        guard let uuid = UUID(uuidString: alarmId) else { return nil }
        let request: NSFetchRequest<AlarmConfiguration> = AlarmConfiguration.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        return try context.fetch(request).first
    }

    // MARK: - The four production query shapes

    @Test func snoozeLookupFindsAlarmOnSQLiteStore() async throws {
        try await withSQLiteStore { container in
            let id = UUID()
            try await insertAlarm(id: id, into: container)

            let context = container.newBackgroundContext()
            try await context.perform {
                // AlarmNotificationUtils.scheduleSnooze: fetch alarm, read snooze duration
                let alarm = try fetchAlarm(alarmId: id.uuidString, in: context)
                #expect(alarm != nil, "Snooze lookup must find the alarm on a SQLite store")
                #expect(alarm?.id == id)
            }
        }
    }

    @Test func heavySleeperLookupFindsAlarmOnSQLiteStore() async throws {
        try await withSQLiteStore { container in
            let id = UUID()
            try await insertAlarm(id: id, into: container)

            let context = container.newBackgroundContext()
            try await context.perform {
                // AlarmNotificationHandler.checkHeavySleeperMode: fetch alarm, read flag via KVC
                let alarm = try fetchAlarm(alarmId: id.uuidString, in: context)
                let isHeavySleeper = alarm?.value(forKey: "heavySleeperMode") as? Bool ?? false
                #expect(isHeavySleeper, "Heavy-sleeper lookup must find the alarm and read the flag")
            }
        }
    }

    @Test func followUpSoundLookupFindsAlarmOnSQLiteStore() async throws {
        try await withSQLiteStore { container in
            let id = UUID()
            try await insertAlarm(id: id, into: container)

            let context = container.newBackgroundContext()
            try await context.perform {
                // AlarmNotificationHandler.scheduleFollowUps: fetch alarm, read sound settings
                let alarm = try fetchAlarm(alarmId: id.uuidString, in: context)
                #expect(alarm?.alarmSound == "Alarm_Honk.caf")
                #expect(alarm?.vibrationOnly == false)
                #expect(alarm?.watchHaptics == true)
            }
        }
    }

    @Test func presentAlarmUILookupFindsAlarmOnSQLiteStore() async throws {
        try await withSQLiteStore { container in
            let id = UUID()
            try await insertAlarm(id: id, into: container)

            let context = container.newBackgroundContext()
            try await context.perform {
                // AlarmNotificationHandler.presentActiveAlarmUI: fetch the full object for the UI
                let alarm = try fetchAlarm(alarmId: id.uuidString, in: context)
                #expect(alarm != nil, "Present-UI lookup must find the alarm on a SQLite store")
                #expect(alarm?.name == "Predicate Test Alarm")
            }
        }
    }

    // MARK: - Guard behavior

    @Test func lookupWithNonUUIDStringReturnsNilInsteadOfCrashing() async throws {
        try await withSQLiteStore { container in
            try await insertAlarm(id: UUID(), into: container)

            let context = container.newBackgroundContext()
            try await context.perform {
                // Production guards on UUID(uuidString:) and takes the fallback path
                let alarm = try fetchAlarm(alarmId: "not-a-uuid", in: context)
                #expect(alarm == nil)
            }
        }
    }

    @Test func lookupWithUnknownUUIDReturnsNil() async throws {
        try await withSQLiteStore { container in
            try await insertAlarm(id: UUID(), into: container)

            let context = container.newBackgroundContext()
            try await context.perform {
                let alarm = try fetchAlarm(alarmId: UUID().uuidString, in: context)
                #expect(alarm == nil)
            }
        }
    }
}
