import CoreData

extension PersistenceController {
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        
        // Generate preview data
        MockDataGenerator.generatePreviewData()
        
        return controller
    }()
}

#if DEBUG
extension SleepSession {
    static var example: SleepSession {
        let context = PersistenceController.preview.container.viewContext
        let fetchRequest: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \SleepSession.startTime, ascending: false)]
        fetchRequest.fetchLimit = 1
        
        // Return the most recent mock session or create a new one if none exists
        if let session = try? context.fetch(fetchRequest).first {
            return session
        } else {
            MockDataGenerator(context: context).generateMockData(for: AppConstants.MockData.previewGenerationDays)
            // Safely fetch the generated session with fallback
            if let session = try? context.fetch(fetchRequest).first {
                return session
            } else {
                // Create a minimal fallback session if generation failed
                return createFallbackSession(in: context)
            }
        }
    }
    
    private static func createFallbackSession(in context: NSManagedObjectContext) -> SleepSession {
        let session = SleepSession(context: context)
        session.id = UUID()
        session.startTime = Date().addingTimeInterval(-AppConstants.Sleep.targetDuration) // 8 hours ago
        session.endTime = Date()
        session.isActive = false
        session.totalSleepTime = AppConstants.Sleep.targetDuration // 8 hours
        session.sleepEfficiency = 85.0
        session.qualityScore = 75.0
        
        // Save the fallback session
        try? context.save()
        
        return session
    }
}

extension SleepStage {
    static var example: SleepStage {
        let context = PersistenceController.preview.container.viewContext
        let fetchRequest: NSFetchRequest<SleepStage> = SleepStage.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \SleepStage.startTime, ascending: false)]
        fetchRequest.fetchLimit = 1
        
        // Return the most recent mock stage or create a new one
        if let stage = try? context.fetch(fetchRequest).first {
            return stage
        } else {
            let session = SleepSession.example
            let stage = SleepStage(context: context)
            stage.id = UUID()
            stage.startTime = Date()
            stage.endTime = Date().addingTimeInterval(5400) // 1.5 hours from now
            stage.type = "deep"
            stage.session = session
            try? context.save()
            return stage
        }
    }
}

extension DailyMetrics {
    static var example: DailyMetrics {
        let context = PersistenceController.preview.container.viewContext
        let fetchRequest: NSFetchRequest<DailyMetrics> = DailyMetrics.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \DailyMetrics.date, ascending: false)]
        fetchRequest.fetchLimit = 1
        
        if let metrics = try? context.fetch(fetchRequest).first {
            return metrics
        } else {
            let session = SleepSession.example
            let metrics = DailyMetrics(context: context)
            metrics.id = UUID()
            metrics.date = Date()
            metrics.totalSleepTime = 28800 // 8 hours
            metrics.deepSleepTime = 7200 // 2 hours
            metrics.remSleepTime = 5400 // 1.5 hours
            metrics.lightSleepTime = 16200 // 4.5 hours
            metrics.sleepSession = session
            metrics.averageHeartRate = 62
            metrics.averageRespiratoryRate = 16
            metrics.sleepEfficiency = 92
            try? context.save()
            return metrics
        }
    }
}
#endif
