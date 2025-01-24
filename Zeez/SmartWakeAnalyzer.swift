import CoreData
import Combine

/// Analyzes sleep data to determine optimal wake times within the user's set window
class SmartWakeAnalyzer {
    private let context: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    /// Calculate the optimal wake time within the given window
    /// - Parameters:
    ///   - targetTime: The user's set alarm time
    ///   - session: Current sleep session
    ///   - windowMinutes: Minutes before target time to consider (default 30)
    /// - Returns: Optimal wake time and confidence score
    func calculateOptimalWakeTime(
        targetTime: Date,
        session: SleepSession,
        windowMinutes: Int = 30
    ) async throws -> (wakeTime: Date, confidence: Double) {
        // Get all relevant data for analysis
        guard let heartRateData = session.heartRateData?.allObjects as? [HeartRateData],
              let movementData = session.movementData?.allObjects as? [MovementData],
              let respiratoryData = session.respiratoryData?.allObjects as? [RespiratoryData] else {
            throw AppError.insufficientData
        }
        
        // Define wake window
        let windowStart = targetTime.addingTimeInterval(-Double(windowMinutes * 60))
        let candidates = generateWakeTimeCandidates(
            start: windowStart,
            end: targetTime,
            interval: 5 // Check every 5 minutes
        )
        
        var bestTime = targetTime
        var bestScore = 0.0
        
        // Analyze each potential wake time
        for time in candidates {
            let score = try await analyzeSleepState(
                at: time,
                heartRateData: heartRateData,
                movementData: movementData,
                respiratoryData: respiratoryData
            )
            
            if score > bestScore {
                bestScore = score
                bestTime = time
            }
        }
        
        return (wakeTime: bestTime, confidence: bestScore)
    }
    
    /// Analyze the sleep state at a specific time
    private func analyzeSleepState(
        at time: Date,
        heartRateData: [HeartRateData],
        movementData: [MovementData],
        respiratoryData: [RespiratoryData]
    ) async throws -> Double {
        // Get data from the 10-minute window before the time
        let windowStart = time.addingTimeInterval(-600) // 10 minutes
        
        let relevantHR = heartRateData.filter {
            guard let timestamp = $0.timestamp else { return false }
            return timestamp >= windowStart && timestamp <= time
        }
        
        let relevantMovement = movementData.filter {
            guard let timestamp = $0.timestamp else { return false }
            return timestamp >= windowStart && timestamp <= time
        }
        
        let relevantRespiratory = respiratoryData.filter {
            guard let timestamp = $0.timestamp else { return false }
            return timestamp >= windowStart && timestamp <= time
        }
        
        // Calculate various indicators
        let hrScore = calculateHeartRateTransitionScore(relevantHR)
        let movementScore = calculateMovementTransitionScore(relevantMovement)
        let respiratoryScore = calculateRespiratoryTransitionScore(relevantRespiratory)
        
        // Weight and combine scores
        return (hrScore * 0.4) + (movementScore * 0.3) + (respiratoryScore * 0.3)
    }
    
    /// Calculate how suitable the heart rate pattern is for waking
    private func calculateHeartRateTransitionScore(_ data: [HeartRateData]) -> Double {
        guard data.count >= 2 else { return 0.0 }
        
        // Look for natural increase in heart rate
        let sorted = data.sorted { ($0.timestamp ?? Date()) < ($1.timestamp ?? Date()) }
        let hrValues = sorted.map { $0.value }
        
        // Calculate trend
        let trend = calculateTrend(hrValues)
        
        // Ideal: Gradual increase (positive trend)
        // Also consider variability
        let variability = calculateVariability(hrValues)
        
        // Combine trend and variability scores
        let trendScore = min(max(trend * 50, 0), 100) // Normalize to 0-100
        let variabilityScore = min(variability * 10, 100) // Higher variability is good
        
        return (trendScore + variabilityScore) / 2
    }
    
    /// Calculate how suitable the movement pattern is for waking
    private func calculateMovementTransitionScore(_ data: [MovementData]) -> Double {
        guard data.count >= 2 else { return 0.0 }
        
        // Look for slight increases in movement
        let sorted = data.sorted { ($0.timestamp ?? Date()) < ($1.timestamp ?? Date()) }
        let movements = sorted.map { $0.magnitude }
        
        // Calculate recent movement level
        let recentMovements = Array(movements.suffix(3))
        let avgRecentMovement = recentMovements.reduce(0, +) / Double(recentMovements.count)
        
        // Ideal: Some movement but not too much
        switch avgRecentMovement {
        case 0.1...0.3: return 100.0  // Light movement - ideal
        case 0.3...0.5: return 80.0   // Moderate movement
        case 0.0...0.1: return 60.0   // Very little movement
        default: return 40.0          // Too much movement
        }
    }
    
    /// Calculate how suitable the respiratory pattern is for waking
    private func calculateRespiratoryTransitionScore(_ data: [RespiratoryData]) -> Double {
        guard data.count >= 2 else { return 0.0 }
        
        // Look for increased respiratory rate
        let sorted = data.sorted { ($0.timestamp ?? Date()) < ($1.timestamp ?? Date()) }
        let rates = sorted.map { $0.respiratoryRate }
        
        // Calculate trend
        let trend = calculateTrend(rates)
        
        // Ideal: Slight increase in respiratory rate
        switch trend {
        case 0.1...0.3: return 100.0  // Gentle increase - ideal
        case 0.3...0.5: return 80.0   // Moderate increase
        case 0.0...0.1: return 60.0   // No significant change
        default: return 40.0          // Too rapid change
        }
    }
    
    // MARK: - Helper Methods
    
    private func generateWakeTimeCandidates(start: Date, end: Date, interval: Int) -> [Date] {
        var candidates: [Date] = []
        var current = start
        
        while current <= end {
            candidates.append(current)
            current = current.addingTimeInterval(Double(interval * 60))
        }
        
        return candidates
    }
    
    private func calculateTrend(_ values: [Double]) -> Double {
        guard values.count >= 2 else { return 0.0 }
        
        let n = Double(values.count)
        let indices = Array(0..<values.count).map(Double.init)
        
        let sumX = indices.reduce(0, +)
        let sumY = values.reduce(0, +)
        let sumXY = zip(indices, values).map(*).reduce(0, +)
        let sumXX = indices.map { $0 * $0 }.reduce(0, +)
        
        let slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX)
        return slope
    }
    
    private func calculateVariability(_ values: [Double]) -> Double {
        guard values.count >= 2 else { return 0.0 }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDiffs = values.map { pow($0 - mean, 2) }
        return sqrt(squaredDiffs.reduce(0, +) / Double(values.count))
    }
}