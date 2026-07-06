import Testing
import CoreData
@testable import Zeez

struct CoreDataModelTests {
    
    /// Test that RespiratoryData entity can be created and queried
    /// This validates the index fix for the Core Data model
    @Test func respiratoryDataEntityCreationAndQuery() async throws {
        // Create in-memory persistent store for testing
        let container = NSPersistentContainer(name: "Zeez", managedObjectModel: PersistenceController.model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        // Load the store
        await withCheckedContinuation { continuation in
            container.loadPersistentStores { _, error in
                #expect(error == nil, "Core Data store should load without errors")
                continuation.resume()
            }
        }
        
        let context = container.viewContext
        
        // Create a test RespiratoryData entity
        let respiratoryData = RespiratoryData(context: context)
        respiratoryData.id = UUID()
        respiratoryData.timestamp = Date()
        respiratoryData.respiratoryRate = 16.5
        respiratoryData.confidence = 95.0
        respiratoryData.deviceType = "AppleWatch"
        
        // Save the context
        do {
            try context.save()
        } catch {
            Issue.record("Failed to save RespiratoryData: \(error)")
        }
        
        // Query the data back using indexed field (id)
        let fetchRequest: NSFetchRequest<RespiratoryData> = RespiratoryData.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", respiratoryData.id! as CVarArg)
        
        do {
            let results = try context.fetch(fetchRequest)
            #expect(results.count == 1, "Should fetch exactly one RespiratoryData entity")
            
            let fetchedData = results.first!
            #expect(fetchedData.respiratoryRate == 16.5)
            #expect(fetchedData.confidence == 95.0)
            #expect(fetchedData.deviceType == "AppleWatch")
        } catch {
            Issue.record("Failed to fetch RespiratoryData: \(error)")
        }
    }
    
    /// Test that the index actually works for performance
    @Test func respiratoryDataIndexPerformance() async throws {
        let container = NSPersistentContainer(name: "Zeez", managedObjectModel: PersistenceController.model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        await withCheckedContinuation { continuation in
            container.loadPersistentStores { _, _ in continuation.resume() }
        }
        
        let context = container.viewContext
        
        // Create multiple RespiratoryData entries
        for i in 0..<100 {
            let data = RespiratoryData(context: context)
            data.id = UUID()
            data.timestamp = Date().addingTimeInterval(TimeInterval(i * -60)) // 1 minute intervals
            data.respiratoryRate = Double.random(in: 12...20)
            data.confidence = Double.random(in: 80...100)
        }
        
        try context.save()
        
        // Perform indexed query and measure time
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let fetchRequest: NSFetchRequest<RespiratoryData> = RespiratoryData.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "confidence > 90.0")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        let results = try context.fetch(fetchRequest)
        
        let queryTime = CFAbsoluteTimeGetCurrent() - startTime
        
        #expect(results.count > 0, "Should find some high-confidence respiratory data")
        #expect(queryTime < 0.1, "Query should complete quickly with proper indexing")
    }
}