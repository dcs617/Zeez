import Foundation

/// The Experimental Zeez Estimate — a Tier-3 interpretation under
/// `SLEEP_METRICS_CLAIMS_AND_VALIDATION.md`. The written specification this code
/// implements is `ZEEZ_SCORE_SPECIFICATION.md` at the repo root; the two must be
/// changed together, and `ZeezScore.version` must be bumped whenever the inputs,
/// weights, bands, or missing-input policy change.
///
/// The score is never a validated measure of sleep quality, recovery, or health.
enum ZeezScore {
    /// Persisted with every estimate as `SleepQualityScore.calculationVersion`.
    static let version = "ZeezScore-3.0"

    /// Coverage below which no score is produced at all. Required components
    /// (see `ZeezScoreComponent.isRequired`) must additionally all be available.
    static let minimumCoverage: Double = 60.0
}

/// The weighted inputs of the estimate. Weights sum to 1.0 across all cases.
enum ZeezScoreComponent: String, CaseIterable {
    /// Recorded session length against adult duration bands.
    case duration
    /// Asleep time as a fraction of the recording window. Deliberately *not*
    /// "sleep efficiency": the denominator is the recording window, not a
    /// reported in-bed interval (claims rule 6).
    case sleepOpportunity
    /// Duration-weighted share of deep/light/REM within total asleep time.
    case stageDistribution
    /// Count of wake episodes occurring after sleep onset.
    case fragmentation
    /// Recording start to first inferred asleep interval.
    case latency

    var weight: Double {
        switch self {
        case .duration: return 0.25
        case .sleepOpportunity: return 0.30
        case .stageDistribution: return 0.25
        case .fragmentation: return 0.15
        case .latency: return 0.05
        }
    }

    /// Without these the estimate is not produced at all, however high the
    /// remaining coverage. A score assembled from duration alone would be a
    /// number about the clock, not about sleep.
    var isRequired: Bool {
        switch self {
        case .duration, .stageDistribution: return true
        case .sleepOpportunity, .fragmentation, .latency: return false
        }
    }
}

/// Why a component could not be computed. Missing inputs make a component
/// unavailable; they never become a neutral default (claims rule 4).
enum ComponentUnavailableReason: String, Equatable {
    case invalidRecordedInterval
    case noStageIntervals
    case noAsleepIntervals
}

enum ComponentResult: Equatable {
    case available(Double)
    case unavailable(ComponentUnavailableReason)

    var score: Double? {
        guard case let .available(value) = self else { return nil }
        return value
    }
}

struct QualityMetrics: Equatable {
    /// Weighted mean over the *available* components, renormalized by their weights.
    let overallScore: Double
    let components: [ZeezScoreComponent: ComponentResult]

    /// Share of total component weight that was actually available, 0–100.
    let inputCoverage: Double

    /// Input-coverage confidence, 0–100: `inputCoverage` scaled by how many raw
    /// sensor series backed the inference. It describes how complete the inputs
    /// were — never how accurate the method is. Persisted as
    /// `SleepQualityScore.confidenceScore`, which used to be a constant 85.
    let confidence: Double

    let version: String

    func score(for component: ZeezScoreComponent) -> Double? {
        components[component]?.score
    }

    var durationScore: Double? { score(for: .duration) }
    var sleepOpportunityScore: Double? { score(for: .sleepOpportunity) }
    var stageDistributionScore: Double? { score(for: .stageDistribution) }
    var fragmentationScore: Double? { score(for: .fragmentation) }
    var latencyScore: Double? { score(for: .latency) }
}
