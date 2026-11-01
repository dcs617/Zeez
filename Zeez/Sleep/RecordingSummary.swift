import CoreData
import Foundation

/// What Zeez can honestly say about a recorded night, shown when it ends (2026-11-01).
///
/// A phone on the nightstand measures two things: when the recording ran and how loud the
/// room was. So the summary says "Recorded session duration", never time asleep (claims
/// table), and gives noise as the relative index, never decibels (`NoiseIndex`). A sample the
/// meter did not hear is left out, never counted as a quiet room; with none heard, noise is
/// "not measured". Recorded nights get no stages or Zeez score (`ZeezScore-3.1`).
struct RecordingSummary: Equatable {
    let start: Date
    let end: Date
    /// Samples taken, heard or not.
    let sampleCount: Int
    /// Samples in which the meter heard the room.
    let measuredSampleCount: Int
    /// The median noise index over the measured samples, or `nil` when none were measured.
    let typicalNoise: Double?
    let noteCount: Int

    enum NoiseLevel: Equatable {
        case quiet, moderate, noisy

        var description: String {
            switch self {
            case .quiet: return "quiet"
            case .moderate: return "some noise"
            case .noisy: return "noisy"
            }
        }
    }

    var duration: TimeInterval { end.timeIntervalSince(start) }

    /// The share of samples that measured the room, or `nil` when none were taken.
    var noiseCoverage: Double? {
        sampleCount > 0 ? Double(measuredSampleCount) / Double(sampleCount) : nil
    }

    /// Whether part of the night went unmeasured: a call, the alarm, or a lost microphone.
    var hasNoiseGaps: Bool { measuredSampleCount < sampleCount }

    /// The typical noise read against `NoiseIndex`'s heuristic bands, or `nil` when not measured.
    var noiseLevel: NoiseLevel? {
        guard let typicalNoise else { return nil }
        if typicalNoise <= NoiseIndex.quietCeiling { return .quiet }
        if typicalNoise >= NoiseIndex.elevatedFloor { return .noisy }
        return .moderate
    }

    /// `nil` for a session without both times. Must be called on the session's context queue.
    init?(session: SleepSession) {
        guard let start = session.startTime, let end = session.endTime else { return nil }
        let readings = session.environmentalReadings?.allObjects as? [EnvironmentalReading] ?? []
        let measured = readings.compactMap(\.measuredNoiseLevel).sorted()
        self.init(start: start, end: end, sampleCount: readings.count,
                  measuredSampleCount: measured.count,
                  typicalNoise: Self.median(measured),
                  noteCount: session.notes?.count ?? 0)
    }

    init(start: Date, end: Date, sampleCount: Int, measuredSampleCount: Int, typicalNoise: Double?, noteCount: Int) {
        self.start = start
        self.end = end
        self.sampleCount = sampleCount
        self.measuredSampleCount = measuredSampleCount
        self.typicalNoise = typicalNoise
        self.noteCount = noteCount
    }

    private static func median(_ sorted: [Double]) -> Double? {
        guard !sorted.isEmpty else { return nil }
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }
}
