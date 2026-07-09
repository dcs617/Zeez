import Foundation

/// Aggregates Apple Health heart-rate samples into fixed-width time buckets before they
/// are persisted.
///
/// A full night of Apple Watch heart-rate samples can run to thousands of rows, and a
/// 90-day import multiplies that by ninety. Every consumer loads them through a
/// relationship fault, so the cost is paid on each session read. Bucketing makes storage
/// a function of **session length** rather than of source sampling density: a night can
/// never exceed `duration / bucketDuration` rows however densely the watch sampled.
///
/// The stored value is the mean of the samples in its bucket. That is a real reduction in
/// fidelity, and it is why a bucket must stay short enough to preserve the shape of an
/// overnight heart-rate curve. It also means `SleepSession.restingHeartRate` (mean of the
/// lowest 20% of stored readings) is computed over per-bucket means rather than raw
/// samples, so isolated troughs are smoothed. Present these values as reported heart rate
/// for the session, never as beat-to-beat data.
enum HeartRateDownsampler {

    /// One minute. Finer than Apple Watch's typical overnight sampling interval, so the
    /// curve is preserved, while capping an 8-hour night at 480 rows.
    static let bucketDuration: TimeInterval = 60

    struct Sample: Equatable {
        let timestamp: Date
        let value: Double
        let deviceType: String?

        init(timestamp: Date, value: Double, deviceType: String? = nil) {
            self.timestamp = timestamp
            self.value = value
            self.deviceType = deviceType
        }
    }

    struct Reading: Equatable {
        /// Start of the bucket this reading summarizes.
        let timestamp: Date
        /// Mean of the samples that fell in the bucket.
        let value: Double
        /// How many source samples the mean was taken over.
        let sampleCount: Int
        /// Device of the bucket's earliest sample.
        let deviceType: String?
    }

    /// Buckets samples by wall-clock time and averages each bucket.
    ///
    /// Buckets are anchored to the reference date rather than to the first sample, so the
    /// same instant always lands in the same bucket regardless of import order. Output is
    /// sorted by timestamp; empty buckets produce no reading.
    static func downsample(
        _ samples: [Sample],
        bucketDuration: TimeInterval = HeartRateDownsampler.bucketDuration
    ) -> [Reading] {
        guard bucketDuration > 0 else { return [] }

        var buckets: [Int: [Sample]] = [:]
        for sample in samples {
            let index = Int((sample.timestamp.timeIntervalSinceReferenceDate / bucketDuration).rounded(.down))
            buckets[index, default: []].append(sample)
        }

        return buckets.keys.sorted().map { index in
            let bucket = buckets[index]!
            let total = bucket.reduce(0.0) { $0 + $1.value }
            let earliest = bucket.min { $0.timestamp < $1.timestamp }
            return Reading(
                timestamp: Date(timeIntervalSinceReferenceDate: Double(index) * bucketDuration),
                value: total / Double(bucket.count),
                sampleCount: bucket.count,
                deviceType: earliest?.deviceType
            )
        }
    }
}
