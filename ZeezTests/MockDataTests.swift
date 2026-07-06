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
        MockDataGenerator(context: context).generateMockData(for: AppConstants.MockData.testGenerationDays)
        
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
        MockDataGenerator(context: context).generateMockData(for: AppConstants.MockData.previewGenerationDays)
        
        let sessionRequest: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        guard let session = try context.fetch(sessionRequest).first else {
            XCTFail("No session generated")
            return
        }
        
        // Test sleep duration is realistic (between 4 and 12 hours)
        guard let startTime = session.startTime,
              let endTime = session.endTime else {
            XCTFail("Session should have start and end times")
            return
        }
        
        let duration = endTime.timeIntervalSince(startTime)
        XCTAssertGreaterThan(duration, AppConstants.Sleep.minimumDuration) // More than 4 hours
        XCTAssertLessThan(duration, AppConstants.Sleep.maximumDuration)   // Less than 12 hours
        
        // Bounds below are the GENERATOR's design envelopes, not the app's
        // "optimal comfort" validation constants — the mock data deliberately
        // includes realistic excursions (awake-stage HR spikes, day/night
        // temperature swing, daytime noise) that sit outside the comfort
        // ranges, which is what made this test fail against
        // AppConstants.HealthMetrics (2.4).

        // Heart rate: base 58–68 BPM with stage offsets of -10…+25
        // (MockSleepPatternGenerator.heartRateFor) → [48, 93].
        if let heartRateData = session.heartRateData?.allObjects as? [HeartRateData] {
            for data in heartRateData {
                XCTAssertGreaterThanOrEqual(data.value, 40, "Below any plausible sleeping HR")
                XCTAssertLessThanOrEqual(data.value, 100, "Above the generator's max (base 68 + awake 25)")
            }
        }

        // Environment: base temp 18–22 °C ± 2 sinusoidal → [16, 24];
        // base noise 20–40 dB + up to 15 dB daytime variation → [20, 55]
        // (MockEnvironmentalPatternGenerator).
        if let readings = session.environmentalReadings?.allObjects as? [EnvironmentalReading] {
            for reading in readings {
                XCTAssertGreaterThanOrEqual(reading.temperature, 16)
                XCTAssertLessThanOrEqual(reading.temperature, 24)
                XCTAssertGreaterThanOrEqual(reading.noiseLevel, 20)
                XCTAssertLessThanOrEqual(reading.noiseLevel, 55)
            }
        }
    }
}
