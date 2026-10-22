import Foundation
import HealthKit
import Testing
@testable import Zeez

/// The HealthKit sleep anchor: which one to keep after an import, and how it is stored.
/// The rule under test is that Zeez never advances past a deletion it has not applied.
struct HealthKitSleepAnchorTests {

    private struct QueryFailed: Error {}

    // MARK: - nextSleepAnchor

    @Test("A first import starts the feed from the window's anchor")
    func firstImportUsesWindowAnchor() {
        #expect(nextSleepAnchor(stored: nil as Int?, deletionQuery: nil, windowAnchor: 7) == 7)
    }

    @Test("A successful deletions query advances the anchor")
    func successfulDeletionQueryAdvances() {
        #expect(nextSleepAnchor(stored: 3, deletionQuery: .success(9), windowAnchor: 5) == 9)
    }

    @Test("A failed deletions query keeps the stored anchor, so its deletions are reported again")
    func failedDeletionQueryKeepsStoredAnchor() {
        #expect(nextSleepAnchor(stored: 3, deletionQuery: .failure(QueryFailed()), windowAnchor: 9) == nil)
    }

    @Test("With a stored anchor, the window's anchor is never used — it may be past unapplied deletions")
    func windowAnchorNeverReplacesStoredAnchor() {
        #expect(nextSleepAnchor(stored: 3, deletionQuery: nil, windowAnchor: 9) == nil)
        #expect(nextSleepAnchor(stored: 3, deletionQuery: .success(nil), windowAnchor: 9) == nil)
    }

    // MARK: - HealthKitSleepAnchorStore

    private func isolatedDefaults() -> UserDefaults {
        let suite = "HealthKitSleepAnchorTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test("The anchor survives a save and load")
    func anchorRoundTrips() throws {
        let store = HealthKitSleepAnchorStore(defaults: isolatedDefaults())
        #expect(store.load() == nil)

        let anchor = HKQueryAnchor(fromValue: 42)
        store.save(anchor)

        let loaded = try #require(store.load())
        let expected = try NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
        let actual = try NSKeyedArchiver.archivedData(withRootObject: loaded, requiringSecureCoding: true)
        #expect(actual == expected)
    }

    @Test("An unreadable stored anchor loads as none, starting the feed over")
    func unreadableAnchorLoadsAsNone() {
        let defaults = isolatedDefaults()
        defaults.set(Data("not an anchor".utf8), forKey: HealthKitSleepAnchorStore.defaultsKey)

        #expect(HealthKitSleepAnchorStore(defaults: defaults).load() == nil)
    }
}
