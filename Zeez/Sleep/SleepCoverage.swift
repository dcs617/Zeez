import Foundation

/// How many nights in a period have a recording — "Recorded on 5 of the last 7 nights".
///
/// Tier 1 under `SLEEP_METRICS_CLAIMS_AND_VALIDATION.md`: it reports what was recorded, not
/// what it means. A night with no recording is absent from every trend, never a zero, and
/// this is what tells the user how much of the period a trend actually covers
/// (`PARKED_CAPABILITIES.md` §8b).
struct NightCoverage: Equatable {
    struct Session {
        let startTime: Date
        let hasEstimate: Bool
    }

    /// The nights the period covers, ending with the night that contains `now`.
    let nightCount: Int
    /// Nights with at least one completed session.
    let recordedNights: Int
    /// Nights with at least one displayable Experimental Zeez Estimate.
    let nightsWithEstimate: Int

    /// A session belongs to the night of the calendar day twelve hours before it starts, so a
    /// recording begun at 01:00 Tuesday counts toward Monday night and one begun at 22:00
    /// Monday does too. Two sessions on one night count once.
    static func nightKey(for date: Date, calendar: Calendar) -> Date {
        calendar.startOfDay(for: date.addingTimeInterval(-12 * 3600))
    }

    static func calculate(sessions: [Session], nightCount: Int, now: Date,
                          calendar: Calendar = .current) -> NightCoverage {
        let nightCount = max(1, nightCount)
        let lastNight = nightKey(for: now, calendar: calendar)
        let firstNight = calendar.date(byAdding: .day, value: -(nightCount - 1), to: lastNight) ?? lastNight

        var recorded = Set<Date>()
        var estimated = Set<Date>()
        for session in sessions {
            let key = nightKey(for: session.startTime, calendar: calendar)
            guard key >= firstNight, key <= lastNight else { continue }
            recorded.insert(key)
            if session.hasEstimate {
                estimated.insert(key)
            }
        }

        return NightCoverage(
            nightCount: nightCount,
            recordedNights: recorded.count,
            nightsWithEstimate: estimated.count
        )
    }

    /// Nights spanned by a trend range: 7 for a week, 28–31 for a month.
    static func nightCount(from start: Date, to end: Date, calendar: Calendar = .current) -> Int {
        max(1, calendar.dateComponents([.day], from: start, to: end).day ?? 1)
    }

    var summary: String {
        "Recorded on \(recordedNights) of the last \(nightCount) \(nightCount == 1 ? "night" : "nights")"
    }

    var estimateSummary: String {
        switch nightsWithEstimate {
        case 0: return "No experimental Zeez estimates in this period"
        case 1: return "Experimental Zeez estimate available for 1 night"
        default: return "Experimental Zeez estimates available for \(nightsWithEstimate) nights"
        }
    }
}

/// Which inputs a single session actually has, and which are missing.
///
/// Tier 1: each row states whether something was recorded or reported, never what it implies.
/// Missing inputs are listed as missing rather than omitted, so an absent sensor cannot pass for
/// an uneventful night (claims rule 4).
struct SessionInputCoverage: Equatable {
    enum Input: String, CaseIterable, Identifiable {
        case sleepStages
        case timeAsleep
        case inBed
        case heartRate
        case respiratoryRate
        case movement
        case roomEnvironment

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .sleepStages: return "Sleep stages"
            case .timeAsleep: return "Time asleep"
            case .inBed: return "In-bed interval"
            case .heartRate: return "Heart rate"
            case .respiratoryRate: return "Respiratory rate"
            case .movement: return "Movement"
            case .roomEnvironment: return "Room environment"
            }
        }
    }

    enum Status: Equatable {
        case recorded(String)
        case missing(String)

        var isRecorded: Bool {
            if case .recorded = self { return true }
            return false
        }

        var detail: String {
            switch self {
            case .recorded(let detail), .missing(let detail): return detail
            }
        }
    }

    struct Entry: Equatable, Identifiable {
        let input: Input
        let status: Status

        var id: Input { input }
    }

    struct Counts: Equatable {
        /// Typed stage intervals, including awake; `inBed` context rows are excluded.
        var stages = 0
        var heartRate = 0
        var respiratory = 0
        var movement = 0
        var environmental = 0
    }

    let entries: [Entry]

    var recordedCount: Int { entries.filter(\.status.isRecorded).count }

    var summary: String {
        "\(recordedCount) of \(entries.count) inputs recorded"
    }

    static func calculate(isAppleHealthSource: Bool, counts: Counts,
                          metrics: DerivedSleepMetrics) -> SessionInputCoverage {
        func samples(_ count: Int, _ noun: String) -> Status {
            count > 0
                ? .recorded("\(count) \(count == 1 ? noun : noun + "s")")
                : .missing("Not recorded")
        }

        let stages: Status
        if counts.stages == 0 {
            stages = .missing("Not available")
        } else {
            stages = .recorded(isAppleHealthSource ? "Reported by Apple Health" : "Experimental Zeez estimate")
        }

        let timeAsleep: Status
        switch metrics.qualifiedAsleepDuration {
        case .available:
            timeAsleep = .recorded("Reported by Apple Health")
        case .unavailable(.unsupportedSource):
            timeAsleep = .missing("Only available for Apple Health imports")
        case .unavailable:
            timeAsleep = .missing("Not reported")
        }

        let inBed: Status = metrics.reportedInBedDuration.value != nil
            ? .recorded("Reported by Apple Health")
            : .missing("Not reported")

        let statuses: [Input: Status] = [
            .sleepStages: stages,
            .timeAsleep: timeAsleep,
            .inBed: inBed,
            .heartRate: samples(counts.heartRate, "sample"),
            .respiratoryRate: samples(counts.respiratory, "sample"),
            .movement: samples(counts.movement, "sample"),
            .roomEnvironment: samples(counts.environmental, "reading")
        ]
        return SessionInputCoverage(entries: Input.allCases.compactMap { input in
            statuses[input].map { Entry(input: input, status: $0) }
        })
    }
}

extension SleepSession {
    /// Must be called on the session's context queue.
    var inputCoverage: SessionInputCoverage {
        // `inBed` rows are context, not stages (claims rule 6), and normalize to nil.
        let stageRows = (sleepStages?.allObjects as? [SleepStage] ?? [])
            .filter { SleepStageType.normalize($0.stageType) != nil }
        return SessionInputCoverage.calculate(
            isAppleHealthSource: hasSourceReportedStages,
            counts: .init(
                stages: stageRows.count,
                heartRate: heartRateData?.count ?? 0,
                respiratory: respiratoryData?.count ?? 0,
                movement: movementData?.count ?? 0,
                environmental: environmentalReadings?.count ?? 0
            ),
            metrics: derivedSleepMetrics
        )
    }
}
