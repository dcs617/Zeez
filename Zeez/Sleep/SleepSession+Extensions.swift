import Foundation
import os.log

extension SleepSession {
    // MARK: - Time Calculations

    /// Wall-clock span of the recorded session (`endTime - startTime`).
    ///
    /// This is a recorded interval, not time asleep: nothing here establishes that the
    /// user was asleep for any of it. Never label it "time asleep" (claims rule 7) and
    /// never use it as a sleep-efficiency denominator (rule 6). For asleep duration or
    /// efficiency, use `derivedSleepMetrics`, which returns `unavailable` when the
    /// qualifying Apple Health intervals are absent.
    var recordedInterval: TimeInterval {
        guard let startTime = startTime,
              let endTime = endTime else {
            return 0
        }
        return endTime.timeIntervalSince(startTime)
    }

    // MARK: - Score Display Policy

    /// Returns `true` when this session has a quality value that can be displayed.
    ///
    /// - `qualityScore == 0`: awaiting analysis or source-only data with no score.
    /// - `qualityScore == 1.0`: sentinel set by `SleepAnalyzer` for sessions with no sensor
    ///   data; treated as unavailable by all UI consumers.
    /// - `qualityScore > 1.0`: displayable only with a persisted Zeez estimate record. Debug
    ///   mock sessions get one from `MockDataGenerator`, so they need no exception here.
    var hasDisplayableScore: Bool {
        guard qualityScore > 1.0 else { return false }
        return hasZeezEstimatedScore
    }

    var hasZeezEstimatedScore: Bool {
        (qualityScores?.count ?? 0) > 0
    }

    /// The most recent persisted estimate record, which carries its `calculationVersion`.
    var latestQualityScoreRecord: SleepQualityScore? {
        let records = (qualityScores?.allObjects as? [SleepQualityScore]) ?? []
        return records.max { ($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast) }
    }

    /// A displayable estimate produced by the current `ZeezScore.version`. Trends average only
    /// these: an earlier version's scores are not comparable and must not be mixed into a trend
    /// without disclosure (`ZEEZ_SCORE_SPECIFICATION.md` §6).
    var hasCurrentVersionEstimate: Bool {
        hasDisplayableScore && latestQualityScoreRecord?.calculationVersion == ZeezScore.version
    }

    var hasSourceReportedStages: Bool {
        deviceIdentifier?.contains(AppConstants.DataProvenance.healthKitMarker) == true
    }

    var stageSourceDescription: String {
        hasSourceReportedStages ? "Reported by Apple Health" : "Experimental Zeez-estimated stages"
    }

    /// Duration suitable for comparison against a user-selected sleep goal.
    ///
    /// Apple Health imports use asleep stage intervals and exclude `inBed`/awake
    /// context rows. Sessions recorded by Zeez do not have source-reported sleep
    /// duration, so their recorded interval is used as an estimate.
    var durationForSleepGoalComparison: TimeInterval? {
        derivedSleepMetrics.goalComparisonDuration.value
    }

    // MARK: - Heart Rate
    var averageHeartRate: Double {
        guard let heartRateData = heartRateData?.allObjects as? [HeartRateData],
              !heartRateData.isEmpty else {
            return 0
        }
        let totalHeartRate = heartRateData.reduce(0.0) { $0 + $1.value }
        return totalHeartRate / Double(heartRateData.count)
    }
    
    var restingHeartRate: Double {
        guard let heartRateData = heartRateData?.allObjects as? [HeartRateData],
              !heartRateData.isEmpty else {
            return 0
        }
        
        // Calculate resting heart rate (average of lowest 20% of readings)
        let sortedValues = heartRateData.map { $0.value }.sorted()
        let restingCount = max(1, Int(Double(sortedValues.count) * 0.2))
        let restingValues = Array(sortedValues.prefix(restingCount))
        return restingValues.reduce(0.0, +) / Double(restingValues.count)
    }
    
    // MARK: - Sleep Stage Analysis
    var sleepStageDistribution: [(type: String, duration: TimeInterval)] {
        guard let displayable = derivedSleepMetrics.asleepStageComposition.value else {
            return []
        }

        return displayable.map { ($0.key.rawValue, $0.value) }
            .sorted { $0.0 < $1.0 }
    }
    
    // MARK: - Utility Methods
    func isInSameDay(as date: Date) -> Bool {
        guard let startTime = startTime else { return false }
        return Calendar.current.isDate(startTime, inSameDayAs: date)
    }
    
    func isWithinDateRange(from: Date, to: Date) -> Bool {
        guard let startTime = startTime else { return false }
        return startTime >= from && startTime <= to
    }
}
