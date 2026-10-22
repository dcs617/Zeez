import Foundation
import HealthKit
import os.log

/// Where the importer resumes HealthKit's change feed for sleep samples (PARKED_CAPABILITIES §8a).
///
/// HealthKit reports a deleted sample only to an `HKAnchoredObjectQuery`, and only deletions
/// made after the anchor it is given — so the anchor must survive between imports. It is
/// written only after the import that used it has saved: a crash in between replays those
/// deletions next time, which is harmless, whereas advancing it first could skip them for good.
///
/// Known limit: HealthKit may purge its record of a deletion at any time. A deletion purged
/// before the next import is never reported, and that sample stays in Zeez — the same outcome
/// as not propagating deletions at all, never a wrong one.
struct HealthKitSleepAnchorStore {
    static let defaultsKey = "healthKitSleepAnalysisAnchor"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> HKQueryAnchor? {
        guard let data = defaults.data(forKey: Self.defaultsKey) else { return nil }
        do {
            return try NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
        } catch {
            // Starting over is safe: the next import takes a fresh anchor and only deletions
            // made before it go unreported.
            ZeezLogger.error(ZeezLogger.coreData, "Stored HealthKit sleep anchor is unreadable - starting a new one", error: error)
            return nil
        }
    }

    func save(_ anchor: HKQueryAnchor) {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
            defaults.set(data, forKey: Self.defaultsKey)
        } catch {
            ZeezLogger.error(ZeezLogger.coreData, "Could not store the HealthKit sleep anchor", error: error)
        }
    }
}

/// The anchor to keep after an import, or nil to keep the stored one.
///
/// - `stored`: the anchor the deletions query started from; nil before the first import.
/// - `deletionQuery`: that query's outcome and new anchor; nil when it did not run.
/// - `windowAnchor`: the anchor returned with the import window's samples.
///
/// The rule is never to move past a deletion Zeez has not applied. With no stored anchor there
/// is nothing to have missed, so the window's anchor starts the feed — it can only be at or
/// behind HealthKit's latest change, which at worst replays deletions. Once there is one, only
/// a successful deletions query may advance it.
func nextSleepAnchor<Anchor>(
    stored: Anchor?,
    deletionQuery: Result<Anchor?, Error>?,
    windowAnchor: Anchor?
) -> Anchor? {
    guard stored != nil else { return windowAnchor }
    guard case .success(let advanced)? = deletionQuery else { return nil }
    return advanced
}
