import Foundation
import os.log

// MARK: - Time Data Structure
extension SleepSession {
    struct TimelyData {
        let startTime: Date
        let endTime: Date
        let timeInSleep: TimeInterval
        let timeInBed: TimeInterval
        
        init?(session: SleepSession) {
            guard let start = session.startTime,
                  let end = session.endTime else {
                return nil
            }
            self.startTime = start
            self.endTime = end
            self.timeInSleep = end.timeIntervalSince(start)
            self.timeInBed = end.timeIntervalSince(start)
        }
    }
    
    var timelyData: TimelyData? {
        return TimelyData(session: self)
    }
    
    // MARK: - Time Calculations
    var timeInSleep: TimeInterval {
        guard let startTime = startTime,
              let endTime = endTime else {
            return 0
        }
        return endTime.timeIntervalSince(startTime)
    }
    
    var timeInBed: TimeInterval {
        guard let startTime = startTime,
              let endTime = endTime else {
            return 0
        }
        return endTime.timeIntervalSince(startTime)
    }
    
    var timeToFallAsleep: TimeInterval {
        guard let stages = sleepStages?.allObjects as? [SleepStage],
              let firstSleepStage = stages.sorted(by: { $0.startTime ?? Date() < $1.startTime ?? Date() }).first,
              let stageStart = firstSleepStage.startTime,
              let sessionStart = startTime else {
            return AppConstants.Sleep.defaultREMLatency // Default fallback: 25 minutes
        }
        return stageStart.timeIntervalSince(sessionStart)
    }
    
    // MARK: - Score Display Policy

    /// Returns `true` when this session has a quality value that can be displayed.
    ///
    /// - `qualityScore == 0`: awaiting analysis or source-only data with no score.
    /// - `qualityScore == 1.0`: sentinel set by `SleepAnalyzer` for sessions with no sensor
    ///   data; treated as unavailable by all UI consumers.
    /// - `qualityScore > 1.0`: displayable only with a persisted Zeez estimate record.
    /// - Debug mock sessions remain displayable in debug builds for intentional test-data review.
    var hasDisplayableScore: Bool {
        guard qualityScore > 1.0 else { return false }

        #if DEBUG
        if deviceIdentifier?.localizedCaseInsensitiveContains("Mock Data") == true {
            return true
        }
        #endif

        return hasZeezEstimatedScore
    }

    var hasZeezEstimatedScore: Bool {
        (qualityScores?.count ?? 0) > 0
    }

    var hasSourceReportedStages: Bool {
        deviceIdentifier?.contains("HealthKit") == true
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

    // MARK: - Sleep Quality Calculations
    var sleepEfficiency: Double {
        guard timeInBed > 0 else { return 0 }
        return (timeInSleep / timeInBed) * 100
    }
    
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
    
    var totalSleepCycles: Int {
        guard let stages = sleepStages?.allObjects as? [SleepStage] else {
            return 0
        }
        
        let displayableCount = stages.filter { SleepStageType.normalize($0.stageType) != nil }.count
        return displayableCount / 4
    }
    
    // MARK: - Environmental Analysis
    var averageEnvironmentalScore: Double {
        guard let readings = environmentalReadings?.allObjects as? [EnvironmentalReading],
              !readings.isEmpty else {
            return 0
        }
        
        let scores = readings.map { reading -> Double in
            // This is a simplified scoring mechanism
            var score = 100.0
            
            // Temperature optimal range: 18-22°C
            let temp = reading.temperature
            if temp < 18 || temp > 22 {
                score -= 10
            }
            
            // Noise level optimal range: < 40 dB
            let noise = reading.noiseLevel
            if noise > 40 {
                score -= 15
            }
            
            // Light level optimal range: < 10 lux
            let light = reading.lightLevel
            if light > 10 {
                score -= 10
            }
            
            // Humidity optimal range: 30-60%
            let humidity = reading.humidity
            if humidity < 30 || humidity > 60 {
                score -= 10
            }
            
            return max(0, score)
        }
        
        return scores.reduce(0, +) / Double(scores.count)
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
