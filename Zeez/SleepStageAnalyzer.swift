import CoreData
import Combine

/// Responsible for analyzing sleep data to detect and classify sleep stages
class SleepStageAnalyzer {
    private let context: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    /// Analyzes a sleep session to determine sleep stages
    /// - Parameter session: The sleep session to analyze
    /// - Returns: Array of classified sleep stages
    func analyzeSleepStages(for session: SleepSession) async throws -> [SleepStage] {
        guard let heartRateData = session.heartRateData?.allObjects as? [HeartRateData],
              let movementData = session.movementData?.allObjects as? [MovementData],
              let respiratoryData = session.respiratoryData?.allObjects as? [RespiratoryData] else {
            throw AppError.insufficientData
        }
        
        // Sort data chronologically
        let sortedHeartRate = heartRateData.sorted { $0.timestamp ?? Date() < $1.timestamp ?? Date() }
        let sortedMovement = movementData.sorted { $0.timestamp ?? Date() < $1.timestamp ?? Date() }
        let sortedRespiratory = respiratoryData.sorted { $0.timestamp ?? Date() < $1.timestamp ?? Date() }
        
        // Analyze in 30-minute epochs
        let epochs = try await createEpochs(
            heartRate: sortedHeartRate,
            movement: sortedMovement,
            respiratory: sortedRespiratory
        )
        
        return try await classifyStages(epochs: epochs, session: session)
    }
    
    /// Creates analysis epochs from sensor data
    private func createEpochs(
        heartRate: [HeartRateData],
        movement: [MovementData],
        respiratory: [RespiratoryData]
    ) async throws -> [SleepEpoch] {
        // Implementation will analyze data in 30-minute windows
        var epochs: [SleepEpoch] = []
        let epochDuration: TimeInterval = 30 * 60 // 30 minutes
        
        guard let startTime = heartRate.first?.timestamp,
              let endTime = heartRate.last?.timestamp else {
            throw AppError.insufficientData
        }
        
        var currentTime = startTime
        while currentTime < endTime {
            let epochEnd = currentTime.addingTimeInterval(epochDuration)
            
            // Filter data for current epoch
            let epochHeartRate = heartRate.filter { 
                guard let timestamp = $0.timestamp else { return false }
                return timestamp >= currentTime && timestamp < epochEnd
            }
            
            let epochMovement = movement.filter {
                guard let timestamp = $0.timestamp else { return false }
                return timestamp >= currentTime && timestamp < epochEnd
            }
            
            let epochRespiratory = respiratory.filter {
                guard let timestamp = $0.timestamp else { return false }
                return timestamp >= currentTime && timestamp < epochEnd
            }
            
            // Create epoch with filtered data
            let epoch = SleepEpoch(
                startTime: currentTime,
                endTime: epochEnd,
                heartRateData: epochHeartRate,
                movementData: epochMovement,
                respiratoryData: epochRespiratory
            )
            
            epochs.append(epoch)
            currentTime = epochEnd
        }
        
        return epochs
    }
    
    /// Classifies sleep stages based on analyzed epochs
    private func classifyStages(epochs: [SleepEpoch], session: SleepSession) async throws -> [SleepStage] {
        var stages: [SleepStage] = []
        
        for epoch in epochs {
            let stage = try await determineStage(from: epoch)
            
            // Create CoreData SleepStage entity
            let sleepStage = SleepStage(context: context)
            sleepStage.id = UUID()
            sleepStage.startTime = epoch.startTime
            sleepStage.endTime = epoch.endTime
            sleepStage.duration = epoch.endTime.timeIntervalSince(epoch.startTime)
            sleepStage.stageType = stage.rawValue
            sleepStage.confidence = calculateConfidence(for: epoch)
            sleepStage.session = session
            
            stages.append(sleepStage)
        }
        
        try context.save()
        return stages
    }
    
    /// Determines sleep stage from epoch data
    private func determineStage(from epoch: SleepEpoch) async throws -> SleepStageType {
        // Initial implementation using basic heuristics
        // Will be refined with machine learning in future updates
        
        let avgHeartRate = epoch.heartRateData.reduce(0.0) { $0 + $1.value } / Double(epoch.heartRateData.count)
        let avgMovement = epoch.movementData.reduce(0.0) { $0 + $1.magnitude } / Double(epoch.movementData.count)
        let avgRespRate = epoch.respiratoryData.reduce(0.0) { $0 + $1.respiratoryRate } / Double(epoch.respiratoryData.count)
        
        switch (avgHeartRate, avgMovement, avgRespRate) {
        case (let hr, let mv, let rr) where mv < 0.1 && hr < 60 && rr < 12:
            return .deepSleep
        case (let hr, let mv, _) where mv < 0.3 && hr < 70:
            return .lightSleep
        case (let hr, let mv, let rr) where mv < 0.2 && hr > 70 && rr > 15:
            return .rem
        default:
            return .awake
        }
    }
    
    /// Calculates confidence score for stage classification
    private func calculateConfidence(for epoch: SleepEpoch) -> Double {
        // Basic confidence calculation based on data quality
        let hrConfidence = epoch.heartRateData.reduce(0.0) { $0 + $1.confidence } / Double(epoch.heartRateData.count)
        let respConfidence = epoch.respiratoryData.reduce(0.0) { $0 + $1.confidence } / Double(epoch.respiratoryData.count)
        
        return (hrConfidence + respConfidence) / 2.0
    }
}

/// Represents a time window of sleep data for analysis
struct SleepEpoch {
    let startTime: Date
    let endTime: Date
    let heartRateData: [HeartRateData]
    let movementData: [MovementData]
    let respiratoryData: [RespiratoryData]
}
