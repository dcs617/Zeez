import Testing
import Foundation
@testable import Zeez

/// Second-audit B9: heart-rate rows must be bounded by session length, not by how
/// densely the source sampled.
@Suite("Heart rate downsampling (B9)")
struct HeartRateDownsamplerTests {

    private let anchor = Date(timeIntervalSinceReferenceDate: 0)

    private func samples(_ pairs: [(offset: TimeInterval, value: Double)]) -> [HeartRateDownsampler.Sample] {
        pairs.map { .init(timestamp: anchor.addingTimeInterval($0.offset), value: $0.value) }
    }

    @Test("Samples inside one bucket collapse to their mean")
    func samplesInOneBucketAverage() {
        let readings = HeartRateDownsampler.downsample(
            samples([(0, 60), (10, 70), (20, 80)]),
            bucketDuration: 60
        )

        #expect(readings.count == 1)
        #expect(readings[0].value == 70)
        #expect(readings[0].sampleCount == 3)
        #expect(readings[0].timestamp == anchor)
    }

    @Test("Samples in different buckets stay separate and sorted by time")
    func separateBucketsRemainSeparate() {
        let readings = HeartRateDownsampler.downsample(
            samples([(150, 90), (5, 60), (65, 70)]),
            bucketDuration: 60
        )

        #expect(readings.map(\.value) == [60, 70, 90])
        #expect(readings.map(\.timestamp) == [
            anchor, anchor.addingTimeInterval(60), anchor.addingTimeInterval(120)
        ])
    }

    @Test("Row count is bounded by session length, not by source sampling density")
    func rowCountIsBoundedBySessionLength() {
        // One sample per second across an 8-hour night: 28,800 source samples.
        let dense = samples((0..<(8 * 3600)).map { (TimeInterval($0), 60.0 + Double($0 % 20)) })
        let readings = HeartRateDownsampler.downsample(dense, bucketDuration: 60)

        #expect(dense.count == 28_800)
        #expect(readings.count == 8 * 60, "An 8-hour night must never store more than one row per minute")
    }

    @Test("Bucket boundaries are anchored to absolute time, not to the first sample")
    func bucketsAreAnchoredToAbsoluteTime() {
        // Two imports of the same instants in different order must bucket identically.
        let forward = HeartRateDownsampler.downsample(samples([(59, 60), (61, 80)]), bucketDuration: 60)
        let reversed = HeartRateDownsampler.downsample(samples([(61, 80), (59, 60)]), bucketDuration: 60)

        #expect(forward == reversed)
        #expect(forward.count == 2, "59s and 61s straddle the minute boundary")
    }

    @Test("Empty input produces no readings")
    func emptyInputProducesNothing() {
        #expect(HeartRateDownsampler.downsample([]).isEmpty)
    }

    @Test("A non-positive bucket duration cannot divide by zero")
    func nonPositiveBucketIsRejected() {
        #expect(HeartRateDownsampler.downsample(samples([(0, 60)]), bucketDuration: 0).isEmpty)
    }

    @Test("The device of the bucket's earliest sample is retained")
    func earliestSampleSuppliesDeviceType() {
        let readings = HeartRateDownsampler.downsample([
            .init(timestamp: anchor.addingTimeInterval(30), value: 70, deviceType: "Later Watch"),
            .init(timestamp: anchor, value: 60, deviceType: "Apple Watch")
        ], bucketDuration: 60)

        #expect(readings.count == 1)
        #expect(readings[0].deviceType == "Apple Watch")
    }

    @Test("Mean preserves the overnight curve rather than flattening it")
    func meanPreservesShape() {
        // A dip in the middle of the night must survive bucketing.
        let night = samples([(0, 70), (30, 70), (3600, 50), (3630, 50), (7200, 68)])
        let readings = HeartRateDownsampler.downsample(night, bucketDuration: 60)

        #expect(readings.map(\.value) == [70, 50, 68])
    }
}
