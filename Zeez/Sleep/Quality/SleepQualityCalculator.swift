import CoreData
import os.log

struct QualityMetrics {
    let overallScore: Double
    let durationScore: Double
    let efficiencyScore: Double
    let stageDistributionScore: Double
    let fragmentationScore: Double
    let sleepLatencyScore: Double
    
    // Legacy support for existing code
    var restfulnessScore: Double { stageDistributionScore }
}

class SleepQualityCalculator {
    private let session: SleepSession
    
    init(session: SleepSession, context: NSManagedObjectContext) {
        self.session = session
    }
    
    func calculateMetrics() -> QualityMetrics {
        let durationScore = calculateDurationScore()
        let efficiencyScore = calculateSleepEfficiencyScore()
        let stageDistributionScore = calculateStageDistributionScore()
        let fragmentationScore = calculateFragmentationScore()
        let sleepLatencyScore = calculateSleepLatencyScore()
        
        // Research-based weighted scoring
        let overallScore = (
            durationScore * 0.25 +         // 25% - Duration in optimal range
            efficiencyScore * 0.30 +       // 30% - Time actually sleeping vs time in bed
            stageDistributionScore * 0.25 + // 25% - Proper deep sleep and REM distribution
            fragmentationScore * 0.15 +    // 15% - Number of awakenings
            sleepLatencyScore * 0.05       // 5% - Time to fall asleep
        )
        
        // Quality scores are derived health data — debug builds only.
        ZeezLogger.debug(ZeezLogger.sleepTracking, "Quality scores - Overall: \(Int(overallScore)), Duration: \(Int(durationScore)), Efficiency: \(Int(efficiencyScore)), Stages: \(Int(stageDistributionScore)), Fragmentation: \(Int(fragmentationScore)), Latency: \(Int(sleepLatencyScore))")
        
        return QualityMetrics(
            overallScore: overallScore,
            durationScore: durationScore,
            efficiencyScore: efficiencyScore,
            stageDistributionScore: stageDistributionScore,
            fragmentationScore: fragmentationScore,
            sleepLatencyScore: sleepLatencyScore
        )
    }
    
    private func calculateDurationScore() -> Double {
        guard let startTime = session.startTime,
              let endTime = session.endTime else {
            return 0
        }
        
        let duration = endTime.timeIntervalSince(startTime)
        let hours = duration / 3600
        
        // Optimal sleep duration is 7-9 hours for adults
        switch hours {
        case 7.0...9.0:
            return 100.0
        case 6.0..<7.0, 9.0..<10.0:
            return 85.0
        case 5.0..<6.0, 10.0..<11.0:
            return 70.0
        case 4.0..<5.0, 11.0..<12.0:
            return 50.0
        default:
            return 25.0
        }
    }
    
    private func calculateSleepEfficiencyScore() -> Double {
        guard let startTime = session.startTime,
              let endTime = session.endTime,
              let stages = session.sleepStages?.allObjects as? [SleepStage],
              !stages.isEmpty else {
            return 85.0 // Default score if no stage data
        }
        
        let totalTimeInBed = endTime.timeIntervalSince(startTime)
        let awakeStages = stages.filter { SleepStageType.awake.matches($0.stageType) }
        let totalAwakeTime = awakeStages.reduce(0.0) { $0 + $1.duration }
        let actualSleepTime = totalTimeInBed - totalAwakeTime
        
        let efficiency = actualSleepTime / totalTimeInBed
        
        // Sleep efficiency scoring based on research
        switch efficiency {
        case 0.90...1.0:
            return 100.0
        case 0.85..<0.90:
            return 90.0
        case 0.80..<0.85:
            return 80.0
        case 0.75..<0.80:
            return 70.0
        case 0.70..<0.75:
            return 60.0
        default:
            return max(20.0, efficiency * 100) // Minimum 20 points
        }
    }
    
    private func calculateStageDistributionScore() -> Double {
        guard let stages = session.sleepStages?.allObjects as? [SleepStage],
              !stages.isEmpty else {
            return 75.0 // Default moderate score if no stage data
        }
        
        let sleepStages = stages.filter {
            guard let type = SleepStageType.normalize($0.stageType) else { return false }
            return type != .awake
        }
        guard !sleepStages.isEmpty else { return 30.0 }

        let totalSleepStages = Double(sleepStages.count)

        let deepSleepCount = Double(sleepStages.filter { SleepStageType.deepSleep.matches($0.stageType) }.count)
        let lightSleepCount = Double(sleepStages.filter { SleepStageType.lightSleep.matches($0.stageType) }.count)
        let remSleepCount = Double(sleepStages.filter { SleepStageType.rem.matches($0.stageType) }.count)
        
        let deepPercent = deepSleepCount / totalSleepStages
        let lightPercent = lightSleepCount / totalSleepStages
        let remPercent = remSleepCount / totalSleepStages
        
        // Research-based optimal ranges
        let deepScore = scorePercentageInRange(deepPercent, optimal: (0.15, 0.20), acceptable: (0.10, 0.25))
        let lightScore = scorePercentageInRange(lightPercent, optimal: (0.45, 0.55), acceptable: (0.35, 0.65))
        let remScore = scorePercentageInRange(remPercent, optimal: (0.20, 0.25), acceptable: (0.15, 0.30))
        
        ZeezLogger.sleepTracking.debug("Stage distribution - Deep: \(deepPercent*100)%, Light: \(lightPercent*100)%, REM: \(remPercent*100)%")
        
        // Weighted average: Deep sleep most important for quality
        return deepScore * 0.4 + remScore * 0.35 + lightScore * 0.25
    }
    
    private func calculateFragmentationScore() -> Double {
        guard let stages = session.sleepStages?.allObjects as? [SleepStage],
              !stages.isEmpty else {
            return 85.0 // Default score if no stage data
        }
        
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
        
        // Score based on number of wake episodes
        switch wakeEpisodes {
        case 0...1:
            return 100.0
        case 2...3:
            return 85.0
        case 4...5:
            return 70.0
        case 6...8:
            return 55.0
        case 9...12:
            return 40.0
        default:
            return 25.0
        }
    }
    
    private func calculateSleepLatencyScore() -> Double {
        guard let stages = session.sleepStages?.allObjects as? [SleepStage],
              !stages.isEmpty,
              let startTime = session.startTime else {
            return 85.0 // Default score if no stage data
        }
        
        // Find first non-awake stage to estimate sleep onset
        let sortedStages = stages.sorted { ($0.startTime ?? Date.distantPast) < ($1.startTime ?? Date.distantPast) }
        
        guard let firstSleepStage = sortedStages.first(where: {
            guard let type = SleepStageType.normalize($0.stageType) else { return false }
            return type != .awake
        }),
              let sleepOnsetTime = firstSleepStage.startTime else {
            return 50.0 // Poor score if never fell asleep
        }
        
        let sleepLatency = sleepOnsetTime.timeIntervalSince(startTime) / 60 // Convert to minutes
        
        // Sleep latency scoring (time to fall asleep)
        switch sleepLatency {
        case 0...10:
            return 100.0 // Fell asleep quickly (very good)
        case 10...20:
            return 90.0  // Normal sleep latency
        case 20...30:
            return 75.0  // Slightly elevated
        case 30...45:
            return 60.0  // Concerning latency
        case 45...60:
            return 45.0  // Poor sleep onset
        default:
            return 25.0  // Very poor sleep onset (> 1 hour)
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
