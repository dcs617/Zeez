import CoreData

struct QualityMetrics {
    let overallScore: Double
    let durationScore: Double
    let cycleScore: Double
    let consistencyScore: Double
    let environmentalScore: Double
}

class SleepQualityCalculator {
    private let session: SleepSession
    private let context: NSManagedObjectContext
    
    init(session: SleepSession, context: NSManagedObjectContext) {
        self.session = session
        self.context = context
    }
    
    func calculateMetrics() -> QualityMetrics {
        // Default to the session's quality score if available
        let overallScore = session.qualityScore
        
        // Calculate duration score based on target sleep duration
        let durationScore = calculateDurationScore()
        
        // Calculate cycle score based on sleep stages
        let cycleScore = calculateCycleScore()
        
        // Calculate consistency score based on sleep schedule
        let consistencyScore = calculateConsistencyScore()
        
        // Use environmental score from session if available
        let environmentalScore = session.environmentalScore
        
        return QualityMetrics(
            overallScore: overallScore,
            durationScore: durationScore,
            cycleScore: cycleScore,
            consistencyScore: consistencyScore,
            environmentalScore: environmentalScore
        )
    }
    
    private func calculateDurationScore() -> Double {
        guard let startTime = session.startTime,
              let endTime = session.endTime else {
            return 0
        }
        
        let duration = endTime.timeIntervalSince(startTime)
        let hours = duration / 3600
        
        // Score based on recommended 7-9 hours of sleep
        switch hours {
        case 7...9: return 100
        case 6..<7, 9..<10: return 80
        case 5..<6, 10..<11: return 60
        default: return 40
        }
    }
    
    private func calculateCycleScore() -> Double {
        guard let stages = session.sleepStages?.allObjects as? [SleepStage],
              !stages.isEmpty else {
            return 0
        }
        
        let sortedStages = stages.sorted { ($0.startTime ?? Date()) < ($1.startTime ?? Date()) }
        var score = 100.0
        
        // Evaluate stage transitions
        for i in 0..<sortedStages.count-1 {
            guard let currentType = sortedStages[i].stageType,
                  let nextType = sortedStages[i+1].stageType else {
                continue
            }
            
            if !isValidTransition(from: currentType, to: nextType) {
                score -= 5.0
            }
        }
        
        return max(score, 0)
    }
    
    private func calculateConsistencyScore() -> Double {
        let fetchRequest: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "startTime >= %@ AND startTime < %@ AND isActive == NO",
            Calendar.current.date(byAdding: .day, value: -7, to: Date())! as NSDate,
            Date() as NSDate
        )
        
        guard let recentSessions = try? context.fetch(fetchRequest),
              !recentSessions.isEmpty else {
            return 0
        }
        
        let startTimes = recentSessions.compactMap { $0.startTime }
        guard !startTimes.isEmpty else { return 0 }
        
        // Calculate variance in start times
        let calendar = Calendar.current
        let minuteComponents = startTimes.map {
            let components = calendar.dateComponents([.hour, .minute], from: $0)
            return components.hour! * 60 + components.minute!
        }
        
        let average = Double(minuteComponents.reduce(0, +)) / Double(minuteComponents.count)
        let variance = minuteComponents.reduce(0.0) { sum, minute in
            let diff = Double(minute) - average
            return sum + (diff * diff)
        } / Double(minuteComponents.count)
        
        // Score based on consistency (lower variance is better)
        switch variance {
        case 0...900: return 100    // Within 30 minutes
        case 901...3600: return 80  // Within 1 hour
        case 3601...7200: return 60 // Within 2 hours
        default: return 40          // More than 2 hours variation
        }
    }
    
    private func isValidTransition(from: String, to: String) -> Bool {
        let validTransitions: [String: Set<String>] = [
            "AWAKE": ["LIGHT"],
            "LIGHT": ["DEEP", "REM", "AWAKE"],
            "DEEP": ["LIGHT", "AWAKE"],
            "REM": ["LIGHT", "AWAKE"]
        ]
        
        return validTransitions[from]?.contains(to) ?? false
    }
}
