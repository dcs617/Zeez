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
        
        // Run alarm data migration and validation (for heavy sleeper mode and other fixes)
        AlarmDataMigrationHelper.performMigrationAndValidation(context: persistenceController.container.viewContext)

        // One-time removal of legacy un-prefixed notification identifiers (2.7)
        LegacyNotificationCleanup.runOnce()

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
                ZeezLogger.info(ZeezLogger.app, "No sleep sessions found - use Settings > Import Sleep Data or Generate Test Data to add data")
                // REMOVED: Automatic mock data generation 
                // You now control data generation manually via Settings
            } else {
                // Verify quality scores
                fetchRequest.predicate = NSPredicate(format: "qualityScore == 0 OR qualityScore == nil")
                let invalidSessions = try context.count(for: fetchRequest)
                
                if invalidSessions > 0 {
                    ZeezLogger.debug(ZeezLogger.app, "Found \(invalidSessions) sessions without quality scores - keeping existing data")
                    // REMOVED: Automatic data regeneration
                    // Your data is preserved even if quality scores are missing
                }
            }
        } catch {
            ZeezLogger.error(ZeezLogger.app, "Error verifying data integrity", error: error)
        }
        #endif
    }
}
