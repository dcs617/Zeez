import Foundation

/// How much the recorded sleep start time varied over a period — "Your recorded sleep start
/// time varied by about 25 minutes over 12 nights".
///
/// Tier 2 under `SLEEP_METRICS_CLAIMS_AND_VALIDATION.md` (matrix row "Bedtime / wake-time
/// consistency"): a stated calculation over recorded start times. It describes the variation
/// and never grades it. A percentage "consistency" score with "Excellent…" and "Consider
/// stabilizing…" insights used to stand here; the contract lists a fixed quality grade and
/// advice among the language to avoid.
struct SleepStartSpread: Equatable {
    /// Below this many recorded nights the spread is unavailable, not small.
    static let minimumNights = 4

    /// Sample standard deviation of each night's recorded sleep start time, measured around
    /// midnight so 23:50 and 00:10 are 20 minutes apart.
    let standardDeviation: TimeInterval
    /// Recorded nights the spread covers.
    let nights: Int

    /// `nil` below `minimumNights`. A night (`NightCoverage.nightKey`, noon to noon) counts once,
    /// by its longest recording: an afternoon nap shares a night with that evening's bedtime and
    /// is not one.
    static func calculate(recordings: [(start: Date, duration: TimeInterval)],
                          calendar: Calendar = .current) -> SleepStartSpread? {
        var longestByNight: [Date: (start: Date, duration: TimeInterval)] = [:]
        for recording in recordings {
            let night = NightCoverage.nightKey(for: recording.start, calendar: calendar)
            if let longer = longestByNight[night], longer.duration >= recording.duration { continue }
            longestByNight[night] = recording
        }
        guard longestByNight.count >= minimumNights else { return nil }

        // Clock time, not elapsed time since midnight, so a DST night keeps its wall-clock bedtime.
        let clockTimes = longestByNight.values.map { recording -> TimeInterval in
            let components = calendar.dateComponents([.hour, .minute, .second], from: recording.start)
            let hours = TimeInterval(components.hour ?? 0) * 3600
            return hours + TimeInterval(components.minute ?? 0) * 60 + TimeInterval(components.second ?? 0)
        }
        guard let variance = clockTimes.circularVariance(period: 24 * 3600) else { return nil }
        return SleepStartSpread(standardDeviation: variance.squareRoot(), nights: longestByNight.count)
    }

    var minutes: Int {
        Int((standardDeviation / 60).rounded())
    }
}
