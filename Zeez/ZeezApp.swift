import SwiftUI
import CoreData

@main
struct ZeezApp: App {
    @UIApplicationDelegateAdaptor(ApplicationDelegate.self) var appDelegate
    let persistenceController = PersistenceController.shared
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onAppear {
                    verifyDataIntegrity()
                }
        }
    }
    
    private func verifyDataIntegrity() {
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "startTime != nil AND endTime != nil")
        
        #if DEBUG
        do {
            let sessionsCount = try context.count(for: fetchRequest)
            print("Found \(sessionsCount) valid sleep sessions")
            
            if sessionsCount == 0 {
                // Generate new mock data
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    generateMockData(context: context)
                }
            } else {
                // Verify quality scores
                fetchRequest.predicate = NSPredicate(format: "qualityScore == 0 OR qualityScore == nil")
                let invalidSessions = try context.count(for: fetchRequest)
                
                if invalidSessions > 0 {
                    print("Found \(invalidSessions) sessions without quality scores. Regenerating data...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        persistenceController.clearAllData()
                        generateMockData(context: context)
                    }
                }
            }
        } catch {
            print("Error verifying data integrity: \(error)")
            
            // Attempt recovery
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                persistenceController.clearAllData()
                generateMockData(context: context)
            }
        }
        #endif
    }
    
    private func generateMockData(context: NSManagedObjectContext) {
        MockDataGenerator.shared.generateMockData(for: 90)
        
        do {
            try context.save()
            print("Generated and saved 90 days of mock data")
            
            // Verify the generation
            let request: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
            request.predicate = NSPredicate(format: "qualityScore > 0")
            let count = try context.count(for: request)
            print("Verified \(count) sessions with quality scores")
        } catch {
            print("Error generating mock data: \(error)")
        }
    }
}
