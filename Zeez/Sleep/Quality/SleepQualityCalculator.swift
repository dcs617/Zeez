import CoreData
import os.log

/// Computes the Experimental Zeez Estimate for a Zeez-recorded session.
///
/// Implements `ZEEZ_SCORE_SPECIFICATION.md`. Two rules govern every branch below:
/// a missing input makes its component `.unavailable` rather than a neutral default,
/// and stage shares are weighted by *duration*, never by how many stage records exist.
///
/// `calculateMetrics()` returns `nil` when the session cannot support an estimate.
/// Callers must not substitute a number in that case.
class SleepQualityCalculator {
    private let session: SleepSession

    init(session: SleepSession, context: NSManagedObjectContext) {
        self.session = session
    }

    func calculateMetrics() -> QualityMetrics? {
        let stages = (session.sleepStages?.allObjects as? [SleepStage]) ?? []
        let asleepStages = stages.filter {
            guard let type = SleepStageType.normalize($0.stageType) else { return false }
            return type != .awake && $0.duration > 0
        }

        let components: [ZeezScoreComponent: ComponentResult] = [
            .duration: durationResult(),
            .sleepOpportunity: sleepOpportunityResult(asleepStages: asleepStages, stages: stages),
            .stageDistribution: stageDistributionResult(asleepStages: asleepStages, stages: stages),
            .fragmentation: fragmentationResult(stages: stages),
            .latency: latencyResult(asleepStages: asleepStages, stages: stages)
        ]

        // Missing-input policy: required components gate the estimate entirely, and the
        // rest shrink coverage. Nothing here falls back to a reassuring default.
        for component in ZeezScoreComponent.allCases where component.isRequired {
            guard components[component]?.score != nil else {
                ZeezLogger.info(ZeezLogger.sleepTracking, "No estimate: required component \(component.rawValue) unavailable")
                return nil
            }
        }

        let availableWeight = components
            .filter { $0.value.score != nil }
            .reduce(0.0) { $0 + $1.key.weight }
        let totalWeight = ZeezScoreComponent.allCases.reduce(0.0) { $0 + $1.weight }
        let coverage = (availableWeight / totalWeight) * 100

        guard coverage >= ZeezScore.minimumCoverage, availableWeight > 0 else {
            ZeezLogger.info(ZeezLogger.sleepTracking, "No estimate: input coverage below minimum")
            return nil
        }

        let weightedSum = components.reduce(0.0) { partial, entry in
            guard let score = entry.value.score else { return partial }
            return partial + score * entry.key.weight
        }
        let overallScore = weightedSum / availableWeight

        let metrics = QualityMetrics(
            overallScore: overallScore,
            components: components,
            inputCoverage: coverage,
            confidence: coverage * sensorBreadthFactor(),
            version: ZeezScore.version
        )

        // Quality scores are derived health data — debug builds only.
        ZeezLogger.debug(
            ZeezLogger.sleepTracking,
            "Estimate \(Int(overallScore)) (coverage \(Int(coverage))%, confidence \(Int(metrics.confidence))%)"
        )
        return metrics
    }

    // MARK: - Confidence

    /// How many raw sensor series backed the stage inference. Stages with no retained
    /// series (imported or regenerated) are trusted least.
    private func sensorBreadthFactor() -> Double {
        let hasMovement = (session.movementData?.count ?? 0) > 0
        let hasHeartRate = (session.heartRateData?.count ?? 0) > 0
        switch (hasMovement, hasHeartRate) {
        case (true, true): return 1.0
        case (true, false), (false, true): return 0.85
        case (false, false): return 0.7
        }
    }

    // MARK: - Components

    private func durationResult() -> ComponentResult {
        guard let startTime = session.startTime,
              let endTime = session.endTime,
              endTime > startTime else {
            return .unavailable(.invalidRecordedInterval)
        }

        let hours = endTime.timeIntervalSince(startTime) / 3600

        // Optimal sleep duration is 7-9 hours for adults
        switch hours {
        case 7.0...9.0: return .available(100.0)
        case 6.0..<7.0, 9.0..<10.0: return .available(85.0)
        case 5.0..<6.0, 10.0..<11.0: return .available(70.0)
        case 4.0..<5.0, 11.0..<12.0: return .available(50.0)
        default: return .available(25.0)
        }
    }

    /// Asleep time over the recording window. The old implementation derived asleep time
    /// as `window - awake`, which silently counted unlabeled gaps as sleep; this sums the
    /// asleep intervals directly.
    private func sleepOpportunityResult(asleepStages: [SleepStage], stages: [SleepStage]) -> ComponentResult {
        guard !stages.isEmpty else { return .unavailable(.noStageIntervals) }
        guard !asleepStages.isEmpty else { return .unavailable(.noAsleepIntervals) }
        guard let startTime = session.startTime,
              let endTime = session.endTime,
              endTime > startTime else {
            return .unavailable(.invalidRecordedInterval)
        }

        let window = endTime.timeIntervalSince(startTime)
        let asleep = asleepStages.reduce(0.0) { $0 + $1.duration }
        let ratio = min(asleep / window, 1.0)

        switch ratio {
        case 0.90...1.0: return .available(100.0)
        case 0.85..<0.90: return .available(90.0)
        case 0.80..<0.85: return .available(80.0)
        case 0.75..<0.80: return .available(70.0)
        case 0.70..<0.75: return .available(60.0)
        default: return .available(max(20.0, ratio * 100))
        }
    }

    /// Duration-weighted stage shares. `asleepUnspecified` stays in the denominator and is
    /// never redistributed into Deep/Light/REM (claims rule 5), so an unspecified-heavy
    /// session correctly scores lower on the typed stages rather than inventing them.
    private func stageDistributionResult(asleepStages: [SleepStage], stages: [SleepStage]) -> ComponentResult {
        guard !stages.isEmpty else { return .unavailable(.noStageIntervals) }
        guard !asleepStages.isEmpty else { return .unavailable(.noAsleepIntervals) }

        let totalAsleep = asleepStages.reduce(0.0) { $0 + $1.duration }
        guard totalAsleep > 0 else { return .unavailable(.noAsleepIntervals) }

        func share(_ type: SleepStageType) -> Double {
            asleepStages
                .filter { type.matches($0.stageType) }
                .reduce(0.0) { $0 + $1.duration } / totalAsleep
        }

        let deepScore = scorePercentageInRange(share(.deepSleep), optimal: (0.15, 0.20), acceptable: (0.10, 0.25))
        let lightScore = scorePercentageInRange(share(.lightSleep), optimal: (0.45, 0.55), acceptable: (0.35, 0.65))
        let remScore = scorePercentageInRange(share(.rem), optimal: (0.20, 0.25), acceptable: (0.15, 0.30))

        // Weighted average: Deep sleep most important for quality
        return .available(deepScore * 0.4 + remScore * 0.35 + lightScore * 0.25)
    }

    private func fragmentationResult(stages: [SleepStage]) -> ComponentResult {
        guard !stages.isEmpty else { return .unavailable(.noStageIntervals) }

        // Count wake episodes during the night (excluding initial and final wake periods)
        let sortedStages = stages.sorted { ($0.startTime ?? Date.distantPast) < ($1.startTime ?? Date.distantPast) }
        var wakeEpisodes = 0
        var inSleep = false

        for stage in sortedStages {
            if SleepStageType.awake.matches(stage.stageType) {
                if inSleep {
                    wakeEpisodes += 1
                    inSleep = false
                }
            } else if SleepStageType.normalize(stage.stageType) != nil {
                inSleep = true
            }
        }

        switch wakeEpisodes {
        case 0...1: return .available(100.0)
        case 2...3: return .available(85.0)
        case 4...5: return .available(70.0)
        case 6...8: return .available(55.0)
        case 9...12: return .available(40.0)
        default: return .available(25.0)
        }
    }

    /// Recording start to first inferred asleep interval. Zeez owns the recording window,
    /// so its start boundary is known — unlike an Apple Watch `inBed` sample, which may
    /// omit boundary awake detail and therefore cannot support a latency claim.
    private func latencyResult(asleepStages: [SleepStage], stages: [SleepStage]) -> ComponentResult {
        guard !stages.isEmpty else { return .unavailable(.noStageIntervals) }
        guard let startTime = session.startTime else { return .unavailable(.invalidRecordedInterval) }

        let onsets = asleepStages.compactMap(\.startTime)
        guard let sleepOnsetTime = onsets.min() else { return .unavailable(.noAsleepIntervals) }

        let latencyMinutes = sleepOnsetTime.timeIntervalSince(startTime) / 60

        switch latencyMinutes {
        case ..<10: return .available(100.0)
        case 10..<20: return .available(90.0)
        case 20..<30: return .available(75.0)
        case 30..<45: return .available(60.0)
        case 45..<60: return .available(45.0)
        default: return .available(25.0)
        }
    }

    private func scorePercentageInRange(_ percentage: Double, optimal: (Double, Double), acceptable: (Double, Double)) -> Double {
        if percentage >= optimal.0 && percentage <= optimal.1 {
            return 100.0
        } else if percentage >= acceptable.0 && percentage <= acceptable.1 {
            // Linear scaling within acceptable range
            let distanceFromOptimal = min(abs(percentage - optimal.0), abs(percentage - optimal.1))
            let acceptableRange = max(optimal.0 - acceptable.0, acceptable.1 - optimal.1)
            return max(70.0, 100.0 - (distanceFromOptimal / acceptableRange * 30.0))
        } else {
            // Poor - outside acceptable range
            return 40.0
        }
    }
}
