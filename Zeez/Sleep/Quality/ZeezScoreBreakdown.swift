import Foundation

/// The per-component explanation of a persisted Experimental Zeez Estimate
/// (`ZEEZ_SCORE_SPECIFICATION.md` §8).
///
/// Components are not persisted — `SleepQualityScore` stores only the composite — so the
/// breakdown is recomputed from the session's stored stages. A recomputation is shown only
/// when it reproduces the stored score under the current `ZeezScore.version`; otherwise the
/// breakdown is unavailable. A breakdown that does not add up to the number beside it would
/// explain a score the user is not looking at.
struct ZeezScoreBreakdown: Equatable {
    struct Entry: Equatable, Identifiable {
        let component: ZeezScoreComponent
        let result: ComponentResult

        var id: ZeezScoreComponent { component }
    }

    enum UnavailableReason: Equatable {
        /// The session has no displayable estimate to explain.
        case noEstimate
        /// The stored estimate was produced under a different specification version.
        case earlierVersion
        /// Recomputing from the stored stages does not reproduce the stored estimate.
        case notReproducible
    }

    enum Availability: Equatable {
        case available(ZeezScoreBreakdown)
        case unavailable(UnavailableReason)
    }

    /// Recomputed scores within this distance of the stored one are the same estimate;
    /// the composite's summation order is not fixed, so exact equality is too strict.
    static let reproductionTolerance = 0.01

    /// Every component, in specification order, including unavailable ones.
    let entries: [Entry]
    let overallScore: Double
    /// Share of total component weight that was available, 0–100.
    let inputCoverage: Double

    var hasUnavailableComponents: Bool {
        entries.contains { $0.result.score == nil }
    }

    /// Must be called on the session's context queue.
    static func make(for session: SleepSession) -> Availability {
        guard session.hasDisplayableScore,
              let context = session.managedObjectContext else {
            return .unavailable(.noEstimate)
        }

        let records = (session.qualityScores?.allObjects as? [SleepQualityScore]) ?? []
        let latest = records.max {
            ($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast)
        }
        guard let latest else { return .unavailable(.notReproducible) }
        guard latest.calculationVersion == ZeezScore.version else {
            return .unavailable(.earlierVersion)
        }

        guard let metrics = SleepQualityCalculator(session: session, context: context).calculateMetrics(),
              abs(metrics.overallScore - session.qualityScore) <= reproductionTolerance else {
            return .unavailable(.notReproducible)
        }

        let entries = ZeezScoreComponent.allCases.compactMap { component in
            metrics.components[component].map { Entry(component: component, result: $0) }
        }
        return .available(ZeezScoreBreakdown(
            entries: entries,
            overallScore: metrics.overallScore,
            inputCoverage: metrics.inputCoverage
        ))
    }
}

// MARK: - Presentation text

/// User-facing wording for the breakdown. Each name describes what was calculated rather
/// than what it means for the user: `sleepOpportunity` is not sleep efficiency (claims
/// rule 6), and `latency` is not "time to fall asleep" (claims matrix, SOL row).
extension ZeezScoreComponent {
    var displayName: String {
        switch self {
        case .duration: return "Recorded session duration"
        case .sleepOpportunity: return "Estimated asleep share of recording"
        case .stageDistribution: return "Estimated stage mix"
        case .fragmentation: return "Estimated wake episodes"
        case .latency: return "Recording start to first estimated sleep"
        }
    }

    var explanation: String {
        switch self {
        case .duration:
            return "Length of the recording, compared with adult duration ranges."
        case .sleepOpportunity:
            return "Time Zeez estimated as asleep, as a share of the whole recording. This is not sleep efficiency."
        case .stageDistribution:
            return "Zeez-estimated Deep, Light and REM time, compared with typical adult ranges."
        case .fragmentation:
            return "Awake periods Zeez estimated after the first estimated sleep. Zeez may not detect every awakening."
        case .latency:
            return "Time from starting the recording to the first interval Zeez estimated as asleep."
        }
    }

    /// The specification weight as a whole percentage, before renormalization.
    var weightPercent: Int {
        Int((weight * 100).rounded())
    }
}

extension ComponentUnavailableReason {
    var displayText: String {
        switch self {
        case .invalidRecordedInterval: return "The recording has no valid start and end"
        case .noStageIntervals: return "No estimated stages for this recording"
        case .noAsleepIntervals: return "No estimated asleep intervals"
        }
    }
}

extension ZeezScoreBreakdown.UnavailableReason {
    var displayText: String {
        switch self {
        case .noEstimate:
            return "No experimental Zeez estimate to explain for this session."
        case .earlierVersion:
            return "This estimate was produced by an earlier version of Zeez's scoring, so its breakdown can't be shown."
        case .notReproducible:
            return "The breakdown for this estimate isn't available."
        }
    }
}
