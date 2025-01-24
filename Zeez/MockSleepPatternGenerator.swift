import Foundation

/// Helper struct for generating realistic mock sleep patterns
struct MockSleepPatternGenerator {
    /// Standard duration for one sleep cycle in seconds (90 minutes)
    static let cycleLength: TimeInterval = 5400
    
    /// Typical distributions of sleep stages within a cycle
    static let stageDistribution: [(type: SleepStageType, portion: Double)] = [
        (.lightSleep, 0.45),  // 45% light sleep
        (.deepSleep, 0.35),   // 35% deep sleep
        (.rem, 0.20)          // 20% REM sleep
    ]
    
    /// Returns a realistic sleep stage progression for a sleep session
    static func generateSleepStagePattern(from startTime: Date, to endTime: Date) -> [(type: SleepStageType, start: Date, end: Date)] {
        guard startTime < endTime else { return [] }
        
        var stages: [(type: SleepStageType, start: Date, end: Date)] = []
        var currentTime = startTime
        
        // Validate total duration isn't too short
        let totalDuration = endTime.timeIntervalSince(startTime)
        guard totalDuration >= 1800 else { return [] } // Minimum 30 minutes
        
        // Start with light sleep (falling asleep period)
        let fallAsleepDuration = min(
            TimeInterval.random(in: 600...1200), // 10-20 minutes
            totalDuration / 4 // Or max 1/4 of total time
        )
        
        stages.append((.lightSleep, currentTime, currentTime.addingTimeInterval(fallAsleepDuration)))
        currentTime = currentTime.addingTimeInterval(fallAsleepDuration)
        
        // Calculate how many full cycles we can fit
        let remainingTime = endTime.timeIntervalSince(currentTime)
        let possibleCycles = Int(remainingTime / cycleLength)
        let adjustedCycles = min(possibleCycles, 6) // Max 6 cycles (9 hours)
        
        // Generate full sleep cycles
        for _ in 0..<adjustedCycles {
            for (type, portion) in stageDistribution {
                let stageDuration = cycleLength * portion
                let stageEnd = min(currentTime.addingTimeInterval(stageDuration), endTime)
                
                // Add some natural variation to stage durations (but ensure we don't exceed endTime)
                let variationFactor = Double.random(in: 0.9...1.1)
                let adjustedEnd = min(
                    Date(timeInterval: stageDuration * (variationFactor - 1), since: stageEnd),
                    endTime
                )
                
                // Only add the stage if it has meaningful duration
                if adjustedEnd.timeIntervalSince(currentTime) >= 60 { // Minimum 1 minute
                    stages.append((type, currentTime, adjustedEnd))
                }
                
                currentTime = adjustedEnd
                
                if currentTime >= endTime { break }
            }
            
            // Add brief awakening with 20% probability between cycles
            if Double.random(in: 0...1) < 0.2 && currentTime < endTime {
                let remainingTime = endTime.timeIntervalSince(currentTime)
                let awakeningDuration = min(
                    TimeInterval.random(in: 120...300), // 2-5 minutes
                    remainingTime / 2 // Or max half of remaining time
                )
                
                if awakeningDuration >= 60 { // Only add if at least 1 minute
                    stages.append((.awake, currentTime, currentTime.addingTimeInterval(awakeningDuration)))
                    currentTime = currentTime.addingTimeInterval(awakeningDuration)
                }
            }
        }
        
        // Fill any remaining time with light sleep
        if currentTime < endTime {
            let remainingDuration = endTime.timeIntervalSince(currentTime)
            if remainingDuration >= 60 {
                stages.append((.lightSleep, currentTime, endTime))
            }
        }
        
        // Validate stages
        stages = stages.filter { stage in
            // Remove any invalid stages
            stage.start < stage.end &&
            stage.end.timeIntervalSince(stage.start) >= 60 && // At least 1 minute
            stage.start >= startTime &&
            stage.end <= endTime
        }
        
        return stages
    }
    
    /// Generate heart rate range for a given sleep stage
    static func heartRateFor(stageType: SleepStageType, baseHR: Double) -> ClosedRange<Double> {
        let safeBaseHR = max(45, min(baseHR, 100)) // Ensure reasonable base HR
        
        switch stageType {
        case .awake:   return (safeBaseHR + 15)...(safeBaseHR + 25)
        case .lightSleep: return (safeBaseHR + 5)...(safeBaseHR + 15)
        case .deepSleep: return (safeBaseHR - 10)...(safeBaseHR)
        case .rem:     return (safeBaseHR + 10)...(safeBaseHR + 20)
        }
    }
    
    /// Generate movement range for a given sleep stage
    static func movementFor(stageType: SleepStageType) -> ClosedRange<Double> {
        switch stageType {
        case .awake:   return 7...10
        case .lightSleep: return 3...6
        case .deepSleep: return 0...2
        case .rem:     return 1...4
        }
    }
    
    /// Generate respiratory rate range for a given sleep stage
    static func respiratoryRateFor(stageType: SleepStageType, baseRate: Double) -> ClosedRange<Double> {
        let safeBaseRate = max(10, min(baseRate, 20)) // Ensure reasonable base rate
        
        switch stageType {
        case .awake:   return (safeBaseRate + 2)...(safeBaseRate + 4)
        case .lightSleep: return safeBaseRate...(safeBaseRate + 2)
        case .deepSleep: return (safeBaseRate - 2)...safeBaseRate
        case .rem:     return (safeBaseRate + 1)...(safeBaseRate + 3)
        }
    }
    
    /// Calculate quality score based on stage distribution and duration
    static func calculateQualityScore(stages: [(type: SleepStageType, start: Date, end: Date)]) -> Double {
        guard !stages.isEmpty else { return 0 }
        
        let totalDuration = stages.reduce(0.0) { sum, stage in
            sum + stage.end.timeIntervalSince(stage.start)
        }
        
        // Return early if duration is unreasonable
        guard totalDuration >= 1800 else { return 0 } // Minimum 30 minutes
        
        var score = 100.0
        
        // Penalize if total duration is outside optimal range (7-9 hours)
        let hoursSlept = totalDuration / 3600
        if hoursSlept < 7 {
            score -= (7 - hoursSlept) * 10
        } else if hoursSlept > 9 {
            score -= (hoursSlept - 9) * 5
        }
        
        // Calculate stage percentages
        let stageDurations = Dictionary(grouping: stages) { $0.type }
            .mapValues { stages in
                stages.reduce(0.0) { sum, stage in
                    sum + stage.end.timeIntervalSince(stage.start)
                }
            }
        
        // Penalize if stage distributions are off target
        for (type, portion) in stageDistribution {
            let actualPortion = (stageDurations[type] ?? 0) / totalDuration
            let difference = abs(actualPortion - portion)
            score -= difference * 20
        }
        
        // Penalize for awake periods
        if let awakeTime = stageDurations[.awake] {
            let awakePortion = awakeTime / totalDuration
            score -= awakePortion * 30
        }
        
        return max(0, min(100, score))
    }
}
