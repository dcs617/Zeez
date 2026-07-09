import Testing
import HealthKit
@testable import Zeez

/// Second-audit B13: three call sites each built their own read scope and had drifted.
/// `SleepSessionManager` requested `restingHeartRate`, which nothing imports.
@Suite("HealthKit authorization scope (B13)")
struct HealthKitAuthorizationTests {

    @Test("The read scope is exactly the three types Zeez imports")
    func readScopeIsMinimal() {
        let expected: Set<HKObjectType> = [
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .respiratoryRate)!
        ]
        #expect(HealthKitAuthorization.readTypes == expected)
    }

    @Test("Resting heart rate is not requested, because nothing imports it")
    func restingHeartRateIsNotRequested() {
        let restingHeartRate = HKObjectType.quantityType(forIdentifier: .restingHeartRate)!
        #expect(!HealthKitAuthorization.readTypes.contains(restingHeartRate))
    }

    @Test("Every requested type corresponds to a Core Data entity Zeez writes")
    func everyRequestedTypeIsConsumed() {
        // sleepAnalysis → SleepStage, heartRate → HeartRateData,
        // respiratoryRate → RespiratoryData. Adding a type without an importer
        // asks the user for data the app never reads.
        #expect(HealthKitAuthorization.readTypes.count == 3)
    }
}
