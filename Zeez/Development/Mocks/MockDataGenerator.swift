import Foundation
import CoreData
import UIKit
import os.log

class MockDataGenerator {
    static let shared = MockDataGenerator()
    private let context: NSManagedObjectContext
    
    // Person-specific base metrics that stay relatively constant
    private let baseHeartRate = Double.random(in: 58...68)
    private let baseRespiratoryRate = Double.random(in: 12...16)
    
    // Sleep schedule tendencies with some natural variation
    private let preferredBedtime = Double.random(in: 21...23)
    private let preferredWakeTime = Double.random(in: 6...8)
    
    // Memory management
    private var sessionsBatchSize = 10
    private var totalSessionsGenerated = 0
    
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
        
        // Monitor memory pressure
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(memoryPressureWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func memoryPressureWarning() {
        ZeezLogger.error(ZeezLogger.mockData, "Memory pressure detected during mock data generation")
        // Reduce batch size to minimize memory usage
        sessionsBatchSize = max(1, sessionsBatchSize / 2)
    }
    
    /// Reset singleton state for testing
    func reset() {
        sessionsBatchSize = 10
        totalSessionsGenerated = 0
    }
    
    func generateMockData(for days: Int) {
        ZeezLogger.info(ZeezLogger.mockData, "Manually generating \(days) days of mock data")
        
        clearMockData()
        
        let calendar = Calendar.current
        let today = Date()
        
        var generatedSessions: [SleepSession] = []
        var sessionsInCurrentBatch = 0
        totalSessionsGenerated = 0
        
        ZeezLogger.info(ZeezLogger.mockData, "Starting mock data generation for \(days) days with batch size \(sessionsBatchSize)")
        
        // Generate sessions in batches to manage memory
        for dayOffset in 0..<days {
            autoreleasepool {
                guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { return }
                
                if let session = createMockSleepSession(for: date) {
                    generatedSessions.append(session)
                    sessionsInCurrentBatch += 1
                    totalSessionsGenerated += 1
                    
                    // Save in batches instead of after each session
                    if sessionsInCurrentBatch >= sessionsBatchSize {
                        saveBatch()
                        sessionsInCurrentBatch = 0
                        
                        ZeezLogger.debug(ZeezLogger.mockData, "Progress: \(totalSessionsGenerated)/\(days) sessions generated")
                    }
                }
            }
        }
        
        // Save any remaining sessions
        if sessionsInCurrentBatch > 0 {
            saveBatch()
        }
        
        // Create weekly metrics
        createWeeklyMetrics(for: generatedSessions)
        
        // Final save to ensure all relationships are persisted
        saveBatch()
        
        // Verify data was saved and log final results
        verifyGeneratedData()
    }
    
    /// Save current batch and manage memory
    private func saveBatch() {
        do {
            try context.save()
            
            // Reset the context to free memory
            context.reset()
            
        } catch {
            ZeezLogger.error(ZeezLogger.mockData, "Error saving batch", error: error)
        }
    }
    
    /// Verify the generated data
    private func verifyGeneratedData() {
        do {
            let request: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
            request.predicate = NSPredicate(format: "qualityScore > 0")
            let count = try context.count(for: request)
            ZeezLogger.info(ZeezLogger.mockData, "Successfully generated \(count) sessions with quality scores")
        } catch {
            ZeezLogger.error(ZeezLogger.mockData, "Error verifying mock data", error: error)
        }
    }
    
    func clearMockData() {
        // Fetch only mock-origin sessions (identified by deviceIdentifier prefix)
        let sessionFetch: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        sessionFetch.predicate = NSPredicate(format: "deviceIdentifier CONTAINS[c] %@", "Mock Data")

        let mockSessions: [SleepSession]
        do {
            mockSessions = try context.fetch(sessionFetch)
        } catch {
            ZeezLogger.error(ZeezLogger.mockData, "Error fetching mock sessions for cleanup", error: error)
            return
        }

        guard !mockSessions.isEmpty else {
            ZeezLogger.info(ZeezLogger.mockData, "No mock sessions to clear")
            return
        }

        // Delete child entities that belong to mock sessions first.
        // NSBatchDeleteRequest bypasses Core Data cascade rules, so we handle
        // child cleanup explicitly before removing the parent sessions.
        let childEntityNames = ["SleepStage", "EnvironmentalReading", "HeartRateData",
                                "MovementData", "RespiratoryData"]
        for entityName in childEntityNames {
            let childRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: entityName)
            childRequest.predicate = NSPredicate(format: "session IN %@", mockSessions)
            do {
                try context.execute(NSBatchDeleteRequest(fetchRequest: childRequest))
            } catch {
                ZeezLogger.error(ZeezLogger.mockData, "Error clearing \(entityName) for mock sessions", error: error)
            }
        }

        // Now batch-delete the mock sessions themselves
        let sessionDeleteRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "SleepSession")
        sessionDeleteRequest.predicate = NSPredicate(format: "deviceIdentifier CONTAINS[c] %@", "Mock Data")
        let batchDelete = NSBatchDeleteRequest(fetchRequest: sessionDeleteRequest)
        batchDelete.resultType = .resultTypeObjectIDs
        do {
            let result = try context.execute(batchDelete) as? NSBatchDeleteResult
            if let objectIDs = result?.result as? [NSManagedObjectID] {
                NSManagedObjectContext.mergeChanges(
                    fromRemoteContextSave: [NSDeletedObjectsKey: objectIDs],
                    into: [context]
                )
            }
        } catch {
            ZeezLogger.error(ZeezLogger.mockData, "Error batch-deleting mock sessions", error: error)
        }

        do {
            try context.save()
        } catch {
            ZeezLogger.error(ZeezLogger.mockData, "Error saving after mock data cleanup", error: error)
        }

        ZeezLogger.info(ZeezLogger.mockData, "Cleared \(mockSessions.count) mock session(s) and related data")
    }

    private func createMockSleepSession(for date: Date) -> SleepSession? {
        let session = SleepSession(context: context)
        let calendar = Calendar.current
        
        // Set session metadata
        session.id = UUID()
        session.createdAt = date
        session.modifiedAt = date
        session.deviceIdentifier = "Mock Data - iPhone"
        session.isActive = false
        
        // Calculate start time (previous evening)
        var startComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let actualBedtime = preferredBedtime + Double.random(in: -0.5...0.5)
        startComponents.hour = Int(actualBedtime)
        startComponents.minute = Int((actualBedtime.truncatingRemainder(dividingBy: 1)) * 60)
        
        guard let startTime = calendar.date(from: startComponents) else {
            context.delete(session)
            return nil
        }
        
        // Calculate end time (next morning)
        var endComponents = startComponents
        guard let currentDay = endComponents.day else {
            ZeezLogger.error(ZeezLogger.mockData, "Could not get day component for mock data generation")
            context.delete(session)
            return nil
        }
        endComponents.day = currentDay + 1  // Next day
        let actualWakeTime = preferredWakeTime + Double.random(in: -0.25...0.25)
        endComponents.hour = Int(actualWakeTime)
        endComponents.minute = Int((actualWakeTime.truncatingRemainder(dividingBy: 1)) * 60)
        
        guard let endTime = calendar.date(from: endComponents),
              endTime > startTime else {
            context.delete(session)
            return nil
        }
        
        session.startTime = startTime
        session.endTime = endTime
        
        // Generate all the data
        let stages = MockSleepPatternGenerator.generateSleepStagePattern(from: startTime, to: endTime)
        generateMockSleepStages(for: session, stages: stages)
        generateMockEnvironmentalReadings(for: session, startTime: startTime, endTime: endTime)
        generateMockHeartRateData(for: session, stages: stages)
        generateMockMovementData(for: session, stages: stages)
        generateMockRespiratoryData(for: session, stages: stages)
        
        // Calculate and set quality score
        session.qualityScore = MockSleepPatternGenerator.calculateQualityScore(stages: stages)
        
        // Create daily metrics
        createMockDailyMetrics(for: session, date: date)
        
        // Save immediately after creating the session and all its relationships
        do {
            try context.save()
        } catch {
            ZeezLogger.error(ZeezLogger.mockData, "Error saving individual session", error: error)
            context.delete(session)
            return nil
        }
        
        return session
    }
    
    private func generateMockSleepStages(for session: SleepSession, stages: [(type: SleepStageType, start: Date, end: Date)]) {
        for stageInfo in stages {
            let stage = SleepStage(context: context)
            stage.id = UUID()
            stage.startTime = stageInfo.start
            stage.endTime = stageInfo.end
            stage.stageType = stageInfo.type.rawValue
            stage.confidence = Double.random(in: 0.7...1.0)
            stage.duration = stageInfo.end.timeIntervalSince(stageInfo.start)
            stage.session = session
        }
    }
    
    private func generateMockEnvironmentalReadings(for session: SleepSession, startTime: Date, endTime: Date) {
        var currentTime = startTime
        let baseReading = MockEnvironmentalPatternGenerator.generateBaseReading()
        var totalScore = 0.0
        var readingCount = 0
        
        while currentTime < endTime {
            let reading = MockEnvironmentalPatternGenerator.addTimeVariation(to: baseReading, at: currentTime)
            let envReading = EnvironmentalReading(context: context)
            
            envReading.id = UUID()
            envReading.timestamp = currentTime
            envReading.temperature = reading.temperature
            envReading.noiseLevel = reading.noise
            envReading.lightLevel = reading.light
            envReading.humidity = reading.humidity
            envReading.deviceType = "iPhone"
            envReading.session = session
            
            totalScore += MockEnvironmentalPatternGenerator.calculateScore(reading: reading)
            readingCount += 1
            
            currentTime = currentTime.addingTimeInterval(AppConstants.MockData.sleepStageInterval) // 15 minutes
        }
        
        session.environmentalScore = totalScore / Double(max(1, readingCount))
    }
    
    private func generateMockHeartRateData(for session: SleepSession, stages: [(type: SleepStageType, start: Date, end: Date)]) {
        for stage in stages {
            var currentTime = stage.start
            let hrRange = MockSleepPatternGenerator.heartRateFor(stageType: stage.type, baseHR: baseHeartRate)
            
            while currentTime < stage.end {
                let heartRate = HeartRateData(context: context)
                heartRate.id = UUID()
                heartRate.timestamp = currentTime
                heartRate.value = Double.random(in: hrRange)
                heartRate.confidence = Double.random(in: 0.8...1.0)
                heartRate.deviceType = "Apple Watch"
                heartRate.samplingRate = 1.0
                heartRate.session = session
                
                currentTime = currentTime.addingTimeInterval(AppConstants.MockData.heartRateInterval) // 5 minutes
            }
        }
    }
    
    private func generateMockMovementData(for session: SleepSession, stages: [(type: SleepStageType, start: Date, end: Date)]) {
        for stage in stages {
            var currentTime = stage.start
            let movementRange = MockSleepPatternGenerator.movementFor(stageType: stage.type)
            
            while currentTime < stage.end {
                let movement = MovementData(context: context)
                movement.id = UUID()
                movement.timestamp = currentTime
                movement.magnitude = Double.random(in: movementRange)
                movement.activityLevel = Int16(min(5, max(0, movement.magnitude / 2)))
                
                let angle = Double.random(in: 0...(2 * .pi))
                let magnitude = movement.magnitude
                movement.xAcceleration = magnitude * cos(angle)
                movement.yAcceleration = magnitude * sin(angle)
                movement.zAcceleration = Double.random(in: -0.5...0.5)
                
                movement.deviceType = "Apple Watch"
                movement.session = session
                
                currentTime = currentTime.addingTimeInterval(AppConstants.MockData.movementInterval) // 1 minute
            }
        }
    }
    
    private func generateMockRespiratoryData(for session: SleepSession, stages: [(type: SleepStageType, start: Date, end: Date)]) {
        for stage in stages {
            var currentTime = stage.start
            let respiratoryRange = MockSleepPatternGenerator.respiratoryRateFor(stageType: stage.type, baseRate: baseRespiratoryRate)
            
            while currentTime < stage.end {
                let respiratory = RespiratoryData(context: context)
                respiratory.id = UUID()
                respiratory.timestamp = currentTime
                respiratory.respiratoryRate = Double.random(in: respiratoryRange)
                respiratory.confidence = Double.random(in: 0.8...1.0)
                respiratory.deviceType = "Apple Watch"
                respiratory.oxygenSaturation = Double.random(in: AppConstants.HealthMetrics.Respiratory.minimumOxygenSaturation...AppConstants.HealthMetrics.Respiratory.maximumOxygenSaturation)
                respiratory.session = session
                
                currentTime = currentTime.addingTimeInterval(AppConstants.MockData.environmentalInterval) // 5 minutes
            }
        }
    }
    
    private func createMockDailyMetrics(for session: SleepSession, date: Date) {
        let metrics = DailyMetrics(context: context)
        metrics.id = UUID()
        metrics.date = date
        metrics.createdAt = date
        metrics.modifiedAt = date
        
        if let endTime = session.endTime,
           let startTime = session.startTime {
            metrics.totalSleepTime = endTime.timeIntervalSince(startTime)
            
            // Calculate sleep debt based on 8-hour target
            let targetSleep: TimeInterval = AppConstants.Sleep.targetDuration
            metrics.sleepDebt = targetSleep - metrics.totalSleepTime
        }
        
        // Calculate averages from session data
        if let heartRateData = session.heartRateData?.allObjects as? [HeartRateData],
           !heartRateData.isEmpty {
            metrics.averageHeartRate = heartRateData.reduce(0.0) { $0 + $1.value } / Double(heartRateData.count)
        }
        
        if let respiratoryData = session.respiratoryData?.allObjects as? [RespiratoryData],
           !respiratoryData.isEmpty {
            metrics.averageRespiratoryRate = respiratoryData.reduce(0.0) { $0 + $1.respiratoryRate } / Double(respiratoryData.count)
        }
        
        metrics.sessions = NSSet(array: [session])
    }
    
    private func createWeeklyMetrics(for sessions: [SleepSession]) {
        let calendar = Calendar.current
        var weeklyMetrics: [Date: WeeklyMetrics] = [:]
        
        for session in sessions {
            guard let startTime = session.startTime else { continue }
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: startTime))!
            
            if weeklyMetrics[weekStart] == nil {
                let weeklyMetric = WeeklyMetrics(context: context)
                weeklyMetric.id = UUID()
                weeklyMetric.weekStartDate = weekStart
                weeklyMetric.weekEndDate = calendar.date(byAdding: .day, value: 7, to: weekStart)
                weeklyMetric.createdAt = startTime
                weeklyMetric.modifiedAt = startTime
                weeklyMetrics[weekStart] = weeklyMetric
            }
            
            if let weeklyMetric = weeklyMetrics[weekStart],
               let dailyMetrics = session.dailyMetrics {
                weeklyMetric.dailyMetrics?.adding(dailyMetrics)
            }
        }
    }
}

// MARK: - Preview Helper
extension MockDataGenerator {
    static func generatePreviewData() {
        let context = PersistenceController.preview.container.viewContext
        let generator = MockDataGenerator(context: context)
        generator.generateMockData(for: 90)
        
        do {
            try context.save()
        } catch {
            ZeezLogger.error(ZeezLogger.mockData, "Error saving preview data", error: error)
        }
    }
}
