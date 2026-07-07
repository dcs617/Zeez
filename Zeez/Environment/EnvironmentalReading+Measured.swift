import Foundation

/// Honesty contract for environmental metrics (roadmap 2.9).
///
/// `EnvironmentalReading`'s numeric attributes are non-optional scalars, so a
/// sentinel marks metrics that were never genuinely measured. iPhones expose no
/// ambient-temperature or humidity sensor, and the old "light level" read camera
/// ISO with no running capture session (a static, meaningless value) — real
/// captures now store `notMeasured` for all three, and only microphone-metered
/// noise is recorded as data. Consumers must aggregate via the `measured*`
/// accessors so absent metrics don't masquerade as freezing/pitch-dark rooms.
/// Mock data still populates real values, which pass through unchanged.
extension EnvironmentalReading {
    /// Sentinel stored when a metric cannot be measured on this hardware.
    static let notMeasured: Double = -1

    var measuredTemperature: Double? { temperature >= 0 ? temperature : nil }
    var measuredHumidity: Double? { humidity >= 0 ? humidity : nil }
    var measuredLightLevel: Double? { lightLevel >= 0 ? lightLevel : nil }
    var measuredNoiseLevel: Double? { noiseLevel >= 0 ? noiseLevel : nil }
}
