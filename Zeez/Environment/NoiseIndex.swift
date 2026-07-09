import Foundation

/// Zeez does not measure calibrated sound pressure, so `EnvironmentalReading.noiseLevel`
/// stores a **relative noise index** on a 0–100 scale rather than decibels.
///
/// The index is derived from the microphone's average power in dBFS (`-160...0`, where
/// `-160` is digital silence and `0` is full scale). It rises monotonically with
/// loudness, but it is not dB SPL: the value depends on the device microphone and its
/// gain, and Zeez has no calibration reference. Never label it "dB", and never compare
/// it against published decibel guidance for sleep environments.
///
/// The `quietCeiling`/`elevatedFloor`/`variabilityThreshold` cutoffs below are
/// heuristics on this uncalibrated scale, not measured acoustic thresholds. Every
/// consumer must read them from here so the monitor, mocks, analyzer, and UI agree.
enum NoiseIndex {
    /// Full range of the stored index.
    static let range: ClosedRange<Double> = 0...100

    /// Suffix for presenting a stored index. Deliberately not a physical unit.
    static let displayUnit = "of 100"

    /// Convert an `AVAudioRecorder` average-power reading (dBFS) to the stored index.
    static func fromAveragePower(_ averagePowerDBFS: Float) -> Double {
        let normalized = (Double(averagePowerDBFS) + 160.0) / 160.0
        return min(max(normalized * 100.0, range.lowerBound), range.upperBound)
    }

    /// At or below this, a room reads as quiet on a typical iPhone microphone.
    static let quietCeiling: Double = 72

    /// At or above this, a room reads as audibly noisy.
    static let elevatedFloor: Double = 82

    /// Index variance above which the room's noise reads as notably variable.
    static let variabilityThreshold: Double = 6
}
