import Foundation

enum SleepMetricProvenance: Equatable {
    case recordedSession
    case appleHealthReported
    case derivedFromAppleHealth
    case experimentalZeezEstimate
}

enum MetricUnavailableReason: Equatable {
    case invalidRecordedInterval
    case noQualifiedAsleepIntervals
    case noReportedInBedIntervals
    case noReportedAwakeIntervals
    case unsupportedSource
    case conflictingAsleepIntervals
    case invalidDenominator
    case invalidGoal
}

enum MetricAvailability<Value> {
    case available(Value, provenance: SleepMetricProvenance)
    case unavailable(MetricUnavailableReason)

    var value: Value? {
        guard case let .available(value, _) = self else { return nil }
        return value
    }

    var provenance: SleepMetricProvenance? {
        guard case let .available(_, provenance) = self else { return nil }
        return provenance
    }
}

struct SleepMetricStageInterval {
    let type: String?
    let startTime: Date?
    let endTime: Date?
    let duration: TimeInterval
}

struct DerivedSleepMetrics {
    let recordedSessionInterval: MetricAvailability<TimeInterval>
    let qualifiedAsleepDuration: MetricAvailability<TimeInterval>
    let reportedInBedDuration: MetricAvailability<TimeInterval>
    let recordedAwakeDuration: MetricAvailability<TimeInterval>
    let asleepStageComposition: MetricAvailability<[SleepStageType: TimeInterval]>
    let sleepEfficiency: MetricAvailability<Double>
    let goalComparisonDuration: MetricAvailability<TimeInterval>
    let hasAppleHealthProvenance: Bool

    func goalShortfall(for selectedGoalDuration: TimeInterval) -> MetricAvailability<TimeInterval> {
        guard selectedGoalDuration > 0 else {
            return .unavailable(.invalidGoal)
        }
        guard let duration = goalComparisonDuration.value,
              let provenance = goalComparisonDuration.provenance else {
            return .unavailable(.noQualifiedAsleepIntervals)
        }
        return .available(max(0, selectedGoalDuration - duration), provenance: provenance)
    }

    static func calculate(
        startTime: Date?,
        endTime: Date?,
        isAppleHealthSource: Bool,
        stages: [SleepMetricStageInterval]
    ) -> DerivedSleepMetrics {
        let recordedInterval: MetricAvailability<TimeInterval>
        if let startTime, let endTime, endTime > startTime {
            recordedInterval = .available(endTime.timeIntervalSince(startTime), provenance: .recordedSession)
        } else {
            recordedInterval = .unavailable(.invalidRecordedInterval)
        }

        let asleepStages = stages.filter {
            guard let type = SleepStageType.normalize($0.type) else { return false }
            return type != .awake && $0.duration > 0
        }
        let inBedStages = stages.filter {
            $0.type?.caseInsensitiveCompare("inBed") == .orderedSame && $0.duration > 0
        }
        let awakeStages = stages.filter {
            SleepStageType.awake.matches($0.type) && $0.duration > 0
        }

        let hasCompositionConflict = containsConflictingOverlap(in: asleepStages)
        let composition: MetricAvailability<[SleepStageType: TimeInterval]>
        if asleepStages.isEmpty {
            composition = .unavailable(.noQualifiedAsleepIntervals)
        } else if hasCompositionConflict {
            composition = .unavailable(.conflictingAsleepIntervals)
        } else {
            let durations = stageDurations(from: asleepStages)
            let provenance: SleepMetricProvenance = isAppleHealthSource
                ? .derivedFromAppleHealth
                : .experimentalZeezEstimate
            composition = durations.isEmpty
                ? .unavailable(.noQualifiedAsleepIntervals)
                : .available(durations, provenance: provenance)
        }

        let qualifiedAsleep: MetricAvailability<TimeInterval>
        if isAppleHealthSource {
            let duration = unionOrStoredDuration(of: asleepStages)
            qualifiedAsleep = duration > 0
                ? .available(duration, provenance: .derivedFromAppleHealth)
                : .unavailable(.noQualifiedAsleepIntervals)
        } else {
            qualifiedAsleep = .unavailable(.unsupportedSource)
        }

        let inBedDuration: MetricAvailability<TimeInterval>
        let reportedInBed = unionOrStoredDuration(of: inBedStages)
        if isAppleHealthSource, reportedInBed > 0 {
            inBedDuration = .available(reportedInBed, provenance: .appleHealthReported)
        } else {
            inBedDuration = .unavailable(.noReportedInBedIntervals)
        }

        let awakeDuration: MetricAvailability<TimeInterval>
        let reportedAwake = unionOrStoredDuration(of: awakeStages)
        if isAppleHealthSource, reportedAwake > 0 {
            awakeDuration = .available(reportedAwake, provenance: .appleHealthReported)
        } else {
            awakeDuration = .unavailable(.noReportedAwakeIntervals)
        }

        let efficiency: MetricAvailability<Double>
        if let asleep = qualifiedAsleep.value, let inBed = inBedDuration.value, inBed > 0, asleep <= inBed {
            efficiency = .available((asleep / inBed) * 100, provenance: .derivedFromAppleHealth)
        } else if inBedDuration.value == nil {
            efficiency = .unavailable(.noReportedInBedIntervals)
        } else {
            efficiency = .unavailable(.invalidDenominator)
        }

        let goalDuration: MetricAvailability<TimeInterval>
        if isAppleHealthSource {
            goalDuration = qualifiedAsleep
        } else {
            goalDuration = recordedInterval
        }

        return DerivedSleepMetrics(
            recordedSessionInterval: recordedInterval,
            qualifiedAsleepDuration: qualifiedAsleep,
            reportedInBedDuration: inBedDuration,
            recordedAwakeDuration: awakeDuration,
            asleepStageComposition: composition,
            sleepEfficiency: efficiency,
            goalComparisonDuration: goalDuration,
            hasAppleHealthProvenance: isAppleHealthSource
        )
    }

    private static func stageDurations(
        from stages: [SleepMetricStageInterval]
    ) -> [SleepStageType: TimeInterval] {
        Dictionary(grouping: stages, by: { SleepStageType.normalize($0.type)! })
            .mapValues { unionOrStoredDuration(of: $0) }
            .filter { $0.value > 0 }
    }

    private static func unionOrStoredDuration(of stages: [SleepMetricStageInterval]) -> TimeInterval {
        let intervals = stages.compactMap { stage -> DateInterval? in
            guard let start = stage.startTime, let end = stage.endTime, end > start else {
                return nil
            }
            return DateInterval(start: start, end: end)
        }
        guard !intervals.isEmpty else {
            return stages.reduce(0) { $0 + max($1.duration, 0) }
        }

        let sorted = intervals.sorted { $0.start < $1.start }
        var total: TimeInterval = 0
        var current = sorted[0]
        for interval in sorted.dropFirst() {
            if interval.start <= current.end {
                current = DateInterval(start: current.start, end: max(current.end, interval.end))
            } else {
                total += current.duration
                current = interval
            }
        }
        return total + current.duration
    }

    private static func containsConflictingOverlap(in stages: [SleepMetricStageInterval]) -> Bool {
        let intervals = stages.compactMap { stage -> (SleepStageType, DateInterval)? in
            guard let type = SleepStageType.normalize(stage.type),
                  let start = stage.startTime,
                  let end = stage.endTime,
                  end > start else {
                return nil
            }
            return (type, DateInterval(start: start, end: end))
        }.sorted { $0.1.start < $1.1.start }

        for (index, current) in intervals.enumerated() {
            for candidate in intervals.dropFirst(index + 1) where candidate.1.start < current.1.end {
                if candidate.0 != current.0 && candidate.1.intersects(current.1) {
                    return true
                }
            }
        }
        return false
    }
}

extension SleepSession {
    var derivedSleepMetrics: DerivedSleepMetrics {
        let stages = (sleepStages?.allObjects as? [SleepStage] ?? []).map {
            SleepMetricStageInterval(
                type: $0.stageType,
                startTime: $0.startTime,
                endTime: $0.endTime,
                duration: $0.duration
            )
        }
        return DerivedSleepMetrics.calculate(
            startTime: startTime,
            endTime: endTime,
            isAppleHealthSource: hasSourceReportedStages,
            stages: stages
        )
    }
}
