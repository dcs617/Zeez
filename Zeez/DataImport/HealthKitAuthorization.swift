import Foundation
import HealthKit

/// The single source of truth for Zeez's HealthKit scope.
///
/// Three call sites used to build their own `typesToRead` set, and they had drifted:
/// `SleepSessionManager` requested `restingHeartRate`, which no code has ever imported
/// (second-audit B13). A permission prompt that asks for data the app never reads is a
/// privacy claim the app does not honour, and it widens the App Privacy questionnaire.
///
/// Add a type here **only** alongside the import code that consumes it.
enum HealthKitAuthorization {

    /// Read-only, and only what Zeez maps into Core Data: sleep sessions (`SleepStage`),
    /// `HeartRateData`, and `RespiratoryData`. Zeez never writes back to Apple Health.
    static var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = []
        if let sleepAnalysis = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleepAnalysis)
        }
        if let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate) {
            types.insert(heartRate)
        }
        if let respiratoryRate = HKObjectType.quantityType(forIdentifier: .respiratoryRate) {
            types.insert(respiratoryRate)
        }
        return types
    }

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Requests read access to `readTypes`.
    ///
    /// Whether the user actually granted a *read* type is deliberately unknowable through
    /// the HealthKit API, so `success` means the prompt completed without a system error —
    /// never that data will be returned.
    static func request(using healthStore: HKHealthStore,
                        completion: @escaping (Bool, Error?) -> Void) {
        healthStore.requestAuthorization(toShare: nil, read: readTypes, completion: completion)
    }

    /// Async form of `request(using:completion:)`. Throws only on system-level failure.
    static func request(using healthStore: HKHealthStore) async throws {
        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
    }
}
