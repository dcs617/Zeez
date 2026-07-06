import Foundation
import os.log

/// Defines the different types of sleep stages tracked by the app.
///
/// Raw values are uppercase (e.g. "AWAKE"). HealthKit and Pillow importers historically
/// stored lowercase values ("awake", "deep", etc.). Use `normalize(_:)` everywhere a
/// stored `stageType` string must be decoded to avoid silent mismatches.
enum SleepStageType: String, CaseIterable {
    case awake = "AWAKE"
    case lightSleep = "LIGHT"
    case asleepUnspecified = "ASLEEP_UNSPECIFIED"
    case deepSleep = "DEEP"
    case rem = "REM"

    var displayName: String {
        switch self {
        case .awake: return "Awake"
        case .lightSleep: return "Light Sleep"
        case .asleepUnspecified: return "Asleep (Unspecified)"
        case .deepSleep: return "Deep Sleep"
        case .rem: return "REM Sleep"
        }
    }

    /// Apple Health names its N1/N2 asleep stage "Core"; Zeez-generated stages
    /// retain the app's existing "Light Sleep" estimate label.
    func displayName(reportedByAppleHealth: Bool) -> String {
        if reportedByAppleHealth, self == .lightSleep {
            return "Core Sleep"
        }
        return displayName
    }

    var description: String {
        switch self {
        case .awake:
            return "Brief periods of wakefulness during sleep cycle"
        case .lightSleep:
            return "Initial stage of sleep where you're easily awakened"
        case .asleepUnspecified:
            return "Sleep reported without a specific stage classification"
        case .deepSleep:
            return "Restorative phase important for physical recovery"
        case .rem:
            return "Rapid Eye Movement sleep, crucial for cognitive function"
        }
    }

    // MARK: - Canonical Decoding

    /// Decode a stored `stageType` string from either uppercase (mock/analyzer-generated)
    /// or lowercase (HealthKit/Pillow-imported) spellings, returning `nil` for unknown values
    /// such as "inBed" or "unknown".
    static func normalize(_ string: String?) -> SleepStageType? {
        guard let string, !string.isEmpty else { return nil }
        if string.caseInsensitiveCompare("asleepUnspecified") == .orderedSame {
            return .asleepUnspecified
        }
        return SleepStageType(rawValue: string.uppercased())
    }

    /// Returns `true` when `stageType` from a `SleepStage` entity refers to this case,
    /// regardless of the stored casing.
    func matches(_ stageTypeString: String?) -> Bool {
        SleepStageType.normalize(stageTypeString) == self
    }
}

struct StoredSleepStageDuration {
    let type: String?
    let duration: TimeInterval
}

/// Returns only actual source-reported or inferred sleep stages. Context intervals such as
/// HealthKit `inBed` do not participate in stage distributions or cycle summaries.
func displayableStageDurations(
    from stages: [StoredSleepStageDuration]
) -> [SleepStageType: TimeInterval] {
    stages.reduce(into: [:]) { distribution, stage in
        guard let type = SleepStageType.normalize(stage.type), stage.duration > 0 else {
            return
        }
        distribution[type, default: 0] += stage.duration
    }
}

/// Returns asleep stages for composition percentages. Awake intervals remain
/// useful context in timelines but do not describe the distribution of sleep.
func asleepStageDurations(
    from stages: [StoredSleepStageDuration]
) -> [SleepStageType: TimeInterval] {
    displayableStageDurations(from: stages).filter { $0.key != .awake }
}

/// Efficiency based on session interval minus awake time is supportable only when an
/// awake interval was actually recorded; stage or in-bed rows alone do not establish it.
func hasRecordedAwakeInterval(in stages: [StoredSleepStageDuration]) -> Bool {
    stages.contains { stage in
        SleepStageType.awake.matches(stage.type) && stage.duration > 0
    }
}
