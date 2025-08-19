import SwiftUI
import CoreData
import os.log

@main
struct ZeezApp: App {
    @UIApplicationDelegateAdaptor(ApplicationDelegate.self) var appDelegate
    let persistenceController = PersistenceController.shared
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onAppear {
                    setupApp()
                }
        }
    }
    
    private func setupApp() {
        verifyDataIntegrity()
        
        // Start alarm system
        AlarmObserver.shared.startObserving(context: persistenceController.container.viewContext)
        ZeezLogger.info(ZeezLogger.alarm, "Alarm system initialized")
    }
    
    private func verifyDataIntegrity() {
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "startTime != nil AND endTime != nil")
        
        #if DEBUG
        do {
            let sessionsCount = try context.count(for: fetchRequest)
            ZeezLogger.debug(ZeezLogger.app, "Found \(sessionsCount) valid sleep sessions")
            
            if sessionsCount == 0 {
                // Generate new mock data
                DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.UI.defaultDelay) {
                    generateMockData(context: context)
                }
            } else {
                // Verify quality scores
                fetchRequest.predicate = NSPredicate(format: "qualityScore == 0 OR qualityScore == nil")
                let invalidSessions = try context.count(for: fetchRequest)
                
                if invalidSessions > 0 {
                    ZeezLogger.debug(ZeezLogger.app, "Found \(invalidSessions) sessions without quality scores. Regenerating data...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.UI.defaultDelay) {
                        persistenceController.clearAllData()
                        generateMockData(context: context)
                    }
                }
            }
        } catch {
            ZeezLogger.error(ZeezLogger.app, "Error verifying data integrity", error: error)
            
            // Attempt recovery
            DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.UI.defaultDelay) {
                persistenceController.clearAllData()
                generateMockData(context: context)
            }
        }
        #endif
    }
    
    private func generateMockData(context: NSManagedObjectContext) {
        MockDataGenerator.shared.generateMockData(for: AppConstants.MockData.defaultGenerationDays)
        
        do {
            try context.save()
            ZeezLogger.info(ZeezLogger.app, "Generated and saved 90 days of mock data")
            
            // Verify the generation
            let request: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
            request.predicate = NSPredicate(format: "qualityScore > 0")
            let count = try context.count(for: request)
            ZeezLogger.info(ZeezLogger.app, "Verified \(count) sessions with quality scores")
        } catch {
            ZeezLogger.error(ZeezLogger.app, "Error generating mock data", error: error)
        }
    }
}
