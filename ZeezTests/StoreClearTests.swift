import CoreData
import Foundation
import Testing
@testable import Zeez

/// Delete All Data — `PersistenceController.clearAllData`, via `recreateStore(at:options:in:)`.
///
/// These drive the static function against temporary directories; `clearAllData` itself only
/// ever acts on the shared container's store.
struct StoreClearTests {

    private static let options: [AnyHashable: Any] = [NSPersistentHistoryTrackingKey: true as NSNumber]

    // MARK: - Fixtures

    private struct OpenStore {
        let coordinator: NSPersistentStoreCoordinator
        let store: NSPersistentStore
        let context: NSManagedObjectContext
    }

    private func sandbox() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("StoreClearTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Open the store at `url` the way the app does (history tracking on, WAL by default).
    private func openStore(at url: URL) throws -> OpenStore {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: PersistenceController.model)
        let store = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: url,
            options: Self.options
        )
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        return OpenStore(coordinator: coordinator, store: store, context: context)
    }

    private func insertSessions(_ count: Int, into context: NSManagedObjectContext) throws {
        try context.performAndWait {
            for index in 0..<count {
                let session = SleepSession(context: context)
                session.id = UUID()
                session.startTime = Date(timeIntervalSince1970: 1_700_000_000 + Double(index) * 86_400)
                session.deviceIdentifier = "StoreClearTests"
            }
            try context.save()
        }
    }

    /// Reads from SQLite, not the context's row cache.
    private func sessionCount(in context: NSManagedObjectContext) throws -> Int {
        try context.performAndWait {
            context.reset()
            return try context.fetch(SleepSession.fetchRequest()).count
        }
    }

    // MARK: - Tests

    @Test("A store cleared while another connection holds its uncheckpointed WAL is empty and usable")
    func clearWhileAnotherConnectionHoldsTheWAL() throws {
        let root = try sandbox()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("Zeez.sqlite")

        // The holder stands in for a second connection on the shared store, such as a widget
        // extension. While it stays open the WAL is never checkpointed, so these sessions
        // exist only in Zeez.sqlite-wal.
        let holder = try openStore(at: url)
        try insertSessions(4, into: holder.context)
        #expect(FileManager.default.fileExists(atPath: url.path + "-wal"),
                "Precondition: an open WAL-mode store must have a -wal sidecar on disk")

        let app = try openStore(at: url)
        try #require(try sessionCount(in: app.context) == 4, "Precondition: the app sees the seeded sessions")

        try PersistenceController.recreateStore(at: url, options: Self.options, in: app.coordinator)

        // Unlinking the database out from under the holder left the new store failing every
        // read (SQLITE_IOERR_SHORT_READ) and save until the holder closed.
        #expect(try sessionCount(in: app.context) == 0, "The cleared store must be readable and empty")
        try insertSessions(1, into: app.context)
        #expect(try sessionCount(in: holder.context) == 1,
                "The other connection must see the cleared store, not its stale copy")

        try holder.coordinator.remove(holder.store)
        for store in app.coordinator.persistentStores {
            try app.coordinator.remove(store)
        }

        let reopened = try openStore(at: url)
        defer { try? reopened.coordinator.remove(reopened.store) }
        #expect(try sessionCount(in: reopened.context) == 1,
                "Only the session saved after the clear may survive a relaunch")
    }

    @Test("Clearing the app's only connection leaves an empty store that survives a relaunch")
    func clearSingleConnection() throws {
        let root = try sandbox()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("Zeez.sqlite")

        let app = try openStore(at: url)
        try insertSessions(3, into: app.context)

        try PersistenceController.recreateStore(at: url, options: Self.options, in: app.coordinator)

        #expect(try sessionCount(in: app.context) == 0)
        #expect(app.coordinator.persistentStores.count == 1, "Exactly one store must be open after the clear")
        for store in app.coordinator.persistentStores {
            try app.coordinator.remove(store)
        }

        let reopened = try openStore(at: url)
        defer { try? reopened.coordinator.remove(reopened.store) }
        #expect(try sessionCount(in: reopened.context) == 0)
    }
}
