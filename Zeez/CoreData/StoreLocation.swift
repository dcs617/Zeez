import CoreData
import Foundation
import os.log

/// Where the Core Data store lives, and how it got there.
///
/// The store originally opened at `NSPersistentContainer`'s default app-container
/// location. A WidgetKit extension cannot read that path — extensions only share a
/// container with the app through an App Group — so the store now lives in the group
/// container and `relocateStore(from:to:)` moves any pre-existing app-container store
/// across on first launch after the upgrade.
///
/// The functions here take explicit URLs rather than reading `PersistenceController`
/// so they can be driven against temporary directories in `StoreRelocationTests`.
enum StoreLocation {
    /// Must match `com.apple.security.application-groups` in `Zeez/Zeez.entitlements`
    /// and the group registered against the team's provisioning profile.
    static let appGroupIdentifier = "group.com.danielsparano.zeez"

    /// `NSPersistentContainer(name: "Zeez")` names its store `Zeez.sqlite`; keeping the
    /// same filename means a relocated store is byte-identical to a fresh one.
    static let storeFileName = "Zeez.sqlite"

    /// SQLite sidecars. Written as suffixes, not path extensions: WAL mode produces
    /// `Zeez.sqlite-wal`, not `Zeez.sqlite.wal`.
    private static let sidecarSuffixes = ["-wal", "-shm"]

    /// The store's home inside the App Group container, or `nil` when the container is
    /// unavailable — which is what an un-entitled process gets, so callers must degrade
    /// rather than force-unwrap.
    static func groupStoreURL(
        groupIdentifier: String = appGroupIdentifier,
        fileManager: FileManager = .default
    ) -> URL? {
        fileManager
            .containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier)?
            .appendingPathComponent(storeFileName)
    }

    /// Move a SQLite store from `source` to `destination`, carrying its `-wal`/`-shm`
    /// sidecars, then destroy the original.
    ///
    /// `replacePersistentStore` is the only supported way to do this: WAL is enabled
    /// (a plain `moveItem` of the `.sqlite` file alone silently drops uncheckpointed
    /// transactions) and history tracking is force-enabled, so both stores must be
    /// opened with `NSPersistentHistoryTrackingKey`.
    ///
    /// - Returns: `true` when a store was moved; `false` when there was nothing to move
    ///   (fresh install) or the destination was already populated (already upgraded).
    @discardableResult
    static func relocateStore(
        from source: URL,
        to destination: URL,
        model: NSManagedObjectModel = PersistenceController.model,
        fileManager: FileManager = .default
    ) throws -> Bool {
        guard fileManager.fileExists(atPath: source.path) else { return false }

        guard !fileManager.fileExists(atPath: destination.path) else {
            ZeezLogger.info(
                ZeezLogger.coreData,
                "Both app-container and App Group stores exist; using the App Group store and leaving the legacy file in place"
            )
            return false
        }

        try fileManager.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let options: [AnyHashable: Any] = [NSPersistentHistoryTrackingKey: true as NSNumber]
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)

        try coordinator.replacePersistentStore(
            at: destination,
            destinationOptions: options,
            withPersistentStoreFrom: source,
            sourceOptions: options,
            type: .sqlite
        )

        try coordinator.destroyPersistentStore(at: source, type: .sqlite, options: options)

        // `destroyPersistentStore` truncates rather than unlinks; clear the husk so a
        // later launch cannot mistake it for a store awaiting relocation.
        try? fileManager.removeItem(at: source)
        for suffix in sidecarSuffixes {
            try? fileManager.removeItem(at: sidecarURL(for: source, suffix: suffix))
        }

        return true
    }

    private static func sidecarURL(for store: URL, suffix: String) -> URL {
        store
            .deletingLastPathComponent()
            .appendingPathComponent(store.lastPathComponent + suffix)
    }
}
