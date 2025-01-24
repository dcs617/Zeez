import XCTest
import CoreData
@testable import Zeez

final class MockDataTests: XCTestCase {
    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!
    
    override func setUpWithError() throws {
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
    }
    
    override func tearDownWithError() throws {
        persistenceController = nil
        context = nil
    }
    
    func testMockDataGeneration() throws {
        // Generate 7 days of mock data
        MockDataGenerator(context: context).generateMockData(for: 7)
        
        // Test SleepSessions
        let sessionRequest: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        let sessions = try context.fetch(sessionRequest)
        XCTAssertEqual(sessions.count, 7, "Should have generated 7 sleep sessions")
        
        // Test first session has all required data
        guard let firstSession = sessions.first else {
            XCTFail("No sessions found")
            return
        }
        
        // Verify session properties
        XCTAssertNotNil(firstSession.startTime)
        XCTAssertNotNil(firstSession.endTime)
        XCTAssertFalse(firstSession.isActive)
        XCTAssertGreaterThan(firstSession.qualityScore, 0)
        
        // Verify relationships
        XCTAssertNotNil(firstSession.sleepStages)
        XCTAssertGreaterThan(firstSession.sleepStages?.count ?? 0, 0)
        XCTAssertNotNil(firstSession.heartRateData)
        XCTAssertGreaterThan(firstSession.heartRateData?.count ?? 0, 0)
        XCTAssertNotNil(firstSession.environmentalReadings)
        XCTAssertGreaterThan(firstSession.environmentalReadings?.count ?? 0, 0)
    }
    
    func testDataRangesAreRealistic() throws {
        MockDataGenerator(context: context).generateMockData(for: 1)
        
        let sessionRequest: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        guard let session = try context.fetch(sessionRequest).first else {
            XCTFail("No session generated")
            return
        }
        
        // Test sleep duration is realistic (between 4 and 12 hours)
        let duration = session.endTime!.timeIntervalSince(session.startTime!)
        XCTAssertGreaterThan(duration, 4 * 3600) // More than 4 hours
        XCTAssertLessThan(duration, 12 * 3600)   // Less than 12 hours
        
        // Test heart rate ranges
        if let heartRateData = session.heartRateData?.allObjects as? [HeartRateData] {
            for data in heartRateData {
                XCTAssertGreaterThanOrEqual(data.value, 45)  // Min heart rate
                XCTAssertLessThanOrEqual(data.value, 75)     // Max heart rate
            }
        }
        
        // Test environmental readings
        if let readings = session.environmentalReadings?.allObjects as? [EnvironmentalReading] {
            for reading in readings {
                XCTAssertGreaterThanOrEqual(reading.temperature, 18)  // Min temp
                XCTAssertLessThanOrEqual(reading.temperature, 24)     // Max temp
                XCTAssertGreaterThanOrEqual(reading.noiseLevel, 20)   // Min noise
                XCTAssertLessThanOrEqual(reading.noiseLevel, 50)      // Max noise
            }
        }
    }
}
