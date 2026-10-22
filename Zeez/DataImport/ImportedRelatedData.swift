import CoreData
import Foundation

/// One respiratory-rate sample, reduced to the values Zeez stores.
struct ImportedRespiratoryReading: Equatable {
    let timestamp: Date
    let rate: Double
    let deviceType: String?
}

/// Store `readings` as the session's heart rate, replacing any it already had. Returns how
/// many were stored. Must run on `context`'s queue; saves.
///
/// Replacing rather than appending is what lets a re-import refresh a night whose range
/// Apple Health changed (§8a): the readings are 60-second buckets with no identity of their
/// own, so there is nothing finer to reconcile. An empty fetch keeps the stored readings —
/// HealthKit returns nothing, not an error, when read access is revoked.
@discardableResult
func storeHeartRateReadings(
    _ readings: [HeartRateDownsampler.Reading],
    forSessionID sessionID: NSManagedObjectID,
    in context: NSManagedObjectContext
) throws -> Int {
    guard let session = try? context.existingObject(with: sessionID) as? SleepSession else {
        throw AppError.dataProcessingFailed
    }
    guard !readings.isEmpty else { return 0 }

    for existing in session.heartRateData as? Set<HeartRateData> ?? [] {
        context.delete(existing)
    }
    for reading in readings {
        let heartRate = HeartRateData(context: context)
        heartRate.id = UUID()
        heartRate.timestamp = reading.timestamp
        heartRate.value = reading.value
        heartRate.deviceType = reading.deviceType ?? "Apple Watch"
        heartRate.confidence = 90.0
        heartRate.session = session
    }
    try context.save()
    return readings.count
}

/// Store `readings` as the session's respiratory rate, replacing any it already had, on the
/// same terms as `storeHeartRateReadings`.
@discardableResult
func storeRespiratoryReadings(
    _ readings: [ImportedRespiratoryReading],
    forSessionID sessionID: NSManagedObjectID,
    in context: NSManagedObjectContext
) throws -> Int {
    guard let session = try? context.existingObject(with: sessionID) as? SleepSession else {
        throw AppError.dataProcessingFailed
    }
    guard !readings.isEmpty else { return 0 }

    for existing in session.respiratoryData as? Set<RespiratoryData> ?? [] {
        context.delete(existing)
    }
    for reading in readings {
        let respiratoryData = RespiratoryData(context: context)
        respiratoryData.id = UUID()
        respiratoryData.timestamp = reading.timestamp
        respiratoryData.respiratoryRate = reading.rate
        respiratoryData.deviceType = reading.deviceType ?? "Apple Watch"
        respiratoryData.confidence = 85.0
        respiratoryData.session = session
    }
    try context.save()
    return readings.count
}
