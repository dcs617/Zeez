import CoreData
import Foundation
import Testing
@testable import Zeez

/// D3a — moving the Core Data store into the App Group container.
///
/// These drive `StoreLocation`'s free functions against temporary directories rather than
/// the real group container, which the test host may not be entitled to reach.
struct StoreRelocationTests {

    // MARK: - Fixtures

    /// A private directory per test; `sandbox()` returns it and registers nothing global.
    private func sandbox() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("StoreRelocationTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Build a SQLite store at `url` holding `sessionCount` sessions, opened the way the
    /// app opens it (history tracking on, WAL by default).
    private func seedStore(at url: URL, sessionCount: Int) throws {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: PersistenceController.model)
        let store = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: url,
            options: [NSPersistentHistoryTrackingKey: true as NSNumber]
        )

        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        try context.performAndWait {
            for index in 0..<sessionCount {
                let session = SleepSession(context: context)
                session.id = UUID()
                session.startTime = Date(timeIntervalSince1970: 1_700_000_000 + Double(index) * 86_400)
                session.endTime = session.startTime?.addingTimeInterval(8 * 3600)
                session.deviceIdentifier = "StoreRelocationTests"
            }
            try context.save()
        }

        try coordinator.remove(store)
    }

    /// Seed a store and leave it open, so its WAL still holds uncheckpointed frames.
    /// SQLite checkpoints on last-connection-close, so this is the only way to reproduce
    /// what an unclean shutdown (crash, force-quit mid-write) leaves on disk.
    /// Returns the live coordinator; the caller must close it.
    private func seedStoreLeavingWALUncheckpointed(
        at url: URL,
        sessionCount: Int
    ) throws -> (NSPersistentStoreCoordinator, NSPersistentStore) {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: PersistenceController.model)
        let store = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: url,
            options: [NSPersistentHistoryTrackingKey: true as NSNumber]
        )

        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        try context.performAndWait {
            for index in 0..<sessionCount {
                let session = SleepSession(context: context)
                session.id = UUID()
                session.startTime = Date(timeIntervalSince1970: 1_700_000_000 + Double(index) * 86_400)
                session.deviceIdentifier = "StoreRelocationTests"
            }
            try context.save()
        }

        return (coordinator, store)
    }

    private func sessionCount(in url: URL) throws -> Int {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: PersistenceController.model)
        let store = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: url,
            options: [NSPersistentHistoryTrackingKey: true as NSNumber]
        )
        defer { try? coordinator.remove(store) }

        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        return try context.performAndWait {
            try context.count(for: SleepSession.fetchRequest())
        }
    }

    // MARK: - Tests

    @Test func relocationMovesEverySessionAndRemovesTheSource() throws {
        let root = try sandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("legacy/Zeez.sqlite")
        try FileManager.default.createDirectory(
            at: source.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let destination = root.appendingPathComponent("group/Zeez.sqlite")

        try seedStore(at: source, sessionCount: 7)

        let moved = try StoreLocation.relocateStore(from: source, to: destination)

        #expect(moved, "A populated source store should report that it was relocated")
        #expect(try sessionCount(in: destination) == 7, "Every session must survive the move")
        #expect(
            !FileManager.default.fileExists(atPath: source.path),
            "The legacy store must be removed, or the next launch will try to relocate it again"
        )
        for suffix in ["-wal", "-shm"] {
            let sidecar = source.deletingLastPathComponent()
                .appendingPathComponent(source.lastPathComponent + suffix)
            #expect(
                !FileManager.default.fileExists(atPath: sidecar.path),
                "Legacy \(suffix) sidecar must be removed alongside the store"
            )
        }
    }

    @Test func relocationCarriesAnUncheckpointedWAL() throws {
        let root = try sandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("Zeez.sqlite")
        let destination = root.appendingPathComponent("group/Zeez.sqlite")

        // Sessions live only in the -wal file at this point. Moving the .sqlite file alone
        // would land an empty store at the destination and lose all four.
        let (coordinator, store) = try seedStoreLeavingWALUncheckpointed(at: source, sessionCount: 4)
        let wal = source.deletingLastPathComponent()
            .appendingPathComponent(source.lastPathComponent + "-wal")
        #expect(
            FileManager.default.fileExists(atPath: wal.path),
            "Precondition: an open WAL-mode store must have a -wal sidecar on disk"
        )

        #expect(try StoreLocation.relocateStore(from: source, to: destination))
        try coordinator.remove(store)

        #expect(
            try sessionCount(in: destination) == 4,
            "Uncheckpointed WAL frames must survive relocation — this is what a force-quit leaves behind"
        )
    }

    @Test func relocationCreatesTheDestinationDirectory() throws {
        let root = try sandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("Zeez.sqlite")
        // Two levels deep and absent — the group container path may not exist yet.
        let destination = root.appendingPathComponent("group/nested/Zeez.sqlite")

        try seedStore(at: source, sessionCount: 1)
        #expect(try StoreLocation.relocateStore(from: source, to: destination))
        #expect(try sessionCount(in: destination) == 1)
    }

    @Test func freshInstallHasNothingToRelocate() throws {
        let root = try sandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("Zeez.sqlite")
        let destination = root.appendingPathComponent("group/Zeez.sqlite")

        #expect(try StoreLocation.relocateStore(from: source, to: destination) == false)
        #expect(
            !FileManager.default.fileExists(atPath: destination.path),
            "A missing source must not conjure an empty destination store"
        )
    }

    @Test func alreadyRelocatedStoreIsLeftAlone() throws {
        let root = try sandbox()
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("Zeez.sqlite")
        let destination = root.appendingPathComponent("group/Zeez.sqlite")
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        // A stale legacy store alongside a populated group store: the group store wins and
        // must not be overwritten by the older data.
        try seedStore(at: source, sessionCount: 2)
        try seedStore(at: destination, sessionCount: 5)

        #expect(try StoreLocation.relocateStore(from: source, to: destination) == false)
        #expect(try sessionCount(in: destination) == 5, "The App Group store must not be clobbered")
        #expect(try sessionCount(in: source) == 2, "The legacy store is left untouched, not destroyed")
    }

    @Test func groupStoreURLIsNilForAnUnentitledGroup() {
        let url = StoreLocation.groupStoreURL(groupIdentifier: "group.com.zeez.not.entitled")
        #expect(url == nil, "An unreachable group container must return nil, not crash")
    }

    @Test func groupStoreURLKeepsTheContainerFilename() throws {
        // NSPersistentContainer(name: "Zeez") names its store Zeez.sqlite; a relocated store
        // must land on the same filename so it is indistinguishable from a fresh one.
        #expect(StoreLocation.storeFileName == "Zeez.sqlite")
        #expect(StoreLocation.appGroupIdentifier == "group.com.danielsparano.zeez")
    }
}
