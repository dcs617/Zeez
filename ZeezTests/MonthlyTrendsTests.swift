import CoreData
import Foundation
import SwiftUI
import Testing
@testable import Zeez

/// The monthly trends chart (`MonthlyTrendsDataProvider`, `MonthlyChartSection`).
///
/// Claims rule 4: a month that cannot support a value is unavailable — left off the chart
/// and out of the insights — never a zero. Rule 10: the estimate keeps its experimental
/// label in the chart, its picker, its insights and VoiceOver.
struct MonthlyTrendsTests {

    // MARK: - Fixtures

    /// Noon on 20 June 2026; the six-month window is January through June.
    private static let now = Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: 20, hour: 12))!

    private func night(month: Int, day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: month, day: day, hour: 22))!
    }

    /// A completed Zeez session, 8 hours unless `hours` says otherwise, with an estimate
    /// persisted the way `SleepAnalyzer` persists one when `estimate` is given.
    @discardableResult
    private func addSession(starting start: Date, hours: Double = 8, estimate: Double? = nil,
                            in context: NSManagedObjectContext) -> SleepSession {
        let session = SleepSession(context: context)
        session.id = UUID()
        session.startTime = start
        session.endTime = start.addingTimeInterval(hours * 3600)
        session.deviceIdentifier = "Manual Session"
        session.isActive = false
        if let estimate {
            session.qualityScore = estimate
            let record = SleepQualityScore(context: context)
            record.id = UUID()
            record.timestamp = session.endTime
            record.overallScore = estimate
            record.calculationVersion = ZeezScore.version
            record.session = session
        }
        return session
    }

    private func monthlyTrends(seed: @escaping (NSManagedObjectContext) -> Void) async throws -> MonthlyTrendData {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.newBackgroundContext()
        try await context.perform {
            seed(context)
            try context.save()
        }
        return try await MonthlyTrendsDataProvider(context: context).fetchMonthlyTrends(now: Self.now)
    }

    private func point(month: Int, in data: MonthlyTrendData) throws -> MonthlyDataPoint {
        try #require(data.dataPoints.first { Calendar.current.component(.month, from: $0.month) == month })
    }

    // MARK: - Missing inputs are unavailable

    @Test("A month without an estimate has no estimate average and is not plotted")
    func monthWithoutEstimateIsUnavailable() async throws {
        let data = try await monthlyTrends { context in
            addSession(starting: night(month: 5, day: 10), estimate: 80, in: context)
            addSession(starting: night(month: 6, day: 10), in: context)  // recorded, no estimate
        }

        #expect(try point(month: 5, in: data).metrics.averageQuality == 80)
        #expect(try point(month: 6, in: data).metrics.averageQuality == nil,
                "A month whose sessions have no estimate must not average to 0")

        let plotted = MonthlyChartSection.plottedValues(for: .quality, in: data.dataPoints)
        #expect(plotted.map(\.value) == [80], "Only May has an estimate to plot")
    }

    @Test("No estimate trend is reported against a month without estimates")
    func noTrendAgainstMissingMonth() async throws {
        let data = try await monthlyTrends { context in
            addSession(starting: night(month: 5, day: 10), estimate: 80, in: context)
            addSession(starting: night(month: 6, day: 10), in: context)
        }

        let trendInsights = data.insights.filter {
            if case .qualityImproving = $0 { return true }
            if case .qualityDeclining = $0 { return true }
            return false
        }
        #expect(trendInsights.isEmpty, "June has no estimates, so there is no change to report")
    }

    @Test("An estimate trend between two estimated months is still reported")
    func trendBetweenEstimatedMonths() async throws {
        let data = try await monthlyTrends { context in
            addSession(starting: night(month: 5, day: 10), estimate: 60, in: context)
            addSession(starting: night(month: 6, day: 10), estimate: 80, in: context)
        }

        #expect(data.insights.contains { if case .qualityImproving = $0 { return true }; return false })
    }

    @Test("Months without sessions have no duration, start time spread or goal shortfall")
    func emptyMonthsAreUnavailable() async throws {
        let data = try await monthlyTrends { context in
            let preferences = UserPreferences(context: context)
            preferences.id = UUID()
            preferences.sleepGoalEnabled = true
            preferences.targetSleepDuration = 8 * 3600
            addSession(starting: night(month: 6, day: 10), in: context)
        }

        let march = try point(month: 3, in: data)
        #expect(march.metrics.averageRecordedDuration == nil)
        #expect(march.metrics.startTimeSpread == nil, "An empty month used to read as 100% consistent")
        #expect(march.sleepDebt == nil, "An empty month has no shortfall to report, not a shortfall of zero")

        let june = try point(month: 6, in: data)
        let juneDuration = try #require(june.metrics.averageRecordedDuration)
        #expect(abs(juneDuration - 8 * 3600) < 1)
        #expect(june.metrics.startTimeSpread == nil, "A spread needs \(SleepStartSpread.minimumNights) recorded nights")
        #expect(june.sleepDebt == 0, "A recorded 8-hour night meets an 8-hour goal")

        for chart in MonthlyChartSection.ChartType.allCases where chart != .quality {
            #expect(MonthlyChartSection.plottedValues(for: chart, in: data.dataPoints).count <= 1,
                    "\(chart) must not plot the five empty months")
        }
    }

    @Test("The monthly duration is recorded session duration, whatever the source")
    func monthlyDurationIsRecordedSessionDuration() async throws {
        let data = try await monthlyTrends { context in
            // Apple Health reports 7 hours asleep inside a 9-hour session.
            let session = addSession(starting: night(month: 6, day: 10), hours: 9, in: context)
            session.deviceIdentifier = AppConstants.DataProvenance.healthKitMarker
            let asleep = SleepStage(context: context)
            asleep.id = UUID()
            asleep.stageType = SleepStageType.lightSleep.rawValue
            asleep.startTime = session.startTime!.addingTimeInterval(3600)
            asleep.endTime = session.startTime!.addingTimeInterval(8 * 3600)
            asleep.duration = 7 * 3600
            asleep.session = session
        }

        let average = try #require(try point(month: 6, in: data).metrics.averageRecordedDuration)
        #expect(abs(average - 9 * 3600) < 1,
                "Plotted \(average / 3600) h: Apple Health time asleep, mixed into a chart of recorded sessions")
        #expect(MonthlyChartSection.ChartType.duration.accessibilityLabel.contains("Recorded session duration"))
    }

    @Test("A night with no asleep time to compare counts as recorded but has no goal shortfall")
    func goalShortfallNeedsAComparableDuration() async throws {
        let data = try await monthlyTrends { context in
            let preferences = UserPreferences(context: context)
            preferences.id = UUID()
            preferences.sleepGoalEnabled = true
            preferences.targetSleepDuration = 8 * 3600
            // Apple Health reported only in-bed time, so there is no time asleep to compare.
            let session = addSession(starting: night(month: 6, day: 10), in: context)
            session.deviceIdentifier = AppConstants.DataProvenance.healthKitMarker
            let inBed = SleepStage(context: context)
            inBed.id = UUID()
            inBed.stageType = "inBed"
            inBed.startTime = session.startTime
            inBed.endTime = session.endTime
            inBed.duration = 8 * 3600
            inBed.session = session
        }

        let june = try point(month: 6, in: data)
        #expect(june.metrics.averageRecordedDuration != nil)
        #expect(june.sleepDebt == nil, "No comparable duration is not a shortfall of zero")
    }

    @Test("Without a selected goal there is no goal shortfall")
    func noGoalNoShortfall() async throws {
        let data = try await monthlyTrends { context in
            addSession(starting: night(month: 6, day: 10), in: context)
            addSession(starting: night(month: 6, day: 12), in: context)
        }

        #expect(try point(month: 6, in: data).sleepDebt == nil)
    }

    // MARK: - Experimental label

    @Test("The estimate keeps its experimental label in the picker, VoiceOver and insights")
    func estimateKeepsExperimentalLabel() async throws {
        let data = try await monthlyTrends { context in
            addSession(starting: night(month: 5, day: 10), estimate: 80, in: context)
            addSession(starting: night(month: 6, day: 10), in: context)
        }

        #expect(MonthlyChartSection.ChartType.quality.rawValue == "Experimental Zeez Estimate")
        #expect(MonthlyChartSection.ChartType.quality.accessibilityLabel.contains("Experimental Zeez estimate"))

        let spoken = MonthlyChartSection.accessibilityValue(for: .quality, in: data.dataPoints)
        #expect(spoken.contains("80 out of 100"))
        #expect(spoken.contains("June 2026: no estimate"), "A month without an estimate is announced as such")
        #expect(!spoken.contains(": 0 out of 100"), "No month may be announced as a zero estimate")

        for insight in [MonthlyInsight.qualityImproving, .qualityDeclining] {
            #expect(insight.description.contains("Experimental Zeez estimate"))
        }
    }

    @Test("A window with no estimates says so instead of announcing values")
    func noEstimatesAnnouncedAsUnavailable() async throws {
        let data = try await monthlyTrends { context in
            addSession(starting: night(month: 6, day: 10), in: context)
        }

        #expect(MonthlyChartSection.plottedValues(for: .quality, in: data.dataPoints).isEmpty)
        #expect(MonthlyChartSection.accessibilityValue(for: .quality, in: data.dataPoints)
                == MonthlyChartSection.ChartType.quality.unavailableText)
    }

    // MARK: - Schedule consistency

    private func start(month: Int, day: Int, hour: Int, minute: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    @Test("The schedule is described as a spread in minutes, never graded or advised on")
    func scheduleIsDescribedNotGraded() async throws {
        // Identical 8-hour nights starting between 22:55 and 23:05: a standard deviation of 4.2 minutes.
        let minutes: [(hour: Int, minute: Int)] = [(22, 55), (23, 0), (23, 5), (23, 0), (22, 55)]
        let data = try await monthlyTrends { context in
            for (offset, time) in minutes.enumerated() {
                addSession(starting: start(month: 6, day: 8 + offset, hour: time.hour, minute: time.minute),
                           in: context)
            }
        }

        let descriptions = data.insights.map(\.description)
        #expect(descriptions.contains("Your recorded sleep start time varied by about 4 minutes over 5 nights this month"),
                "Insights were \(descriptions)")
        for description in descriptions {
            #expect(!description.contains("Excellent") && !description.contains("Consider"),
                    "\"\(description)\" grades or advises (claims matrix, bedtime consistency and insights rows)")
        }
    }

    @Test("A spread needs four recorded nights, and a nap is not a bedtime")
    func spreadNeedsFourNightsAndIgnoresNaps() async throws {
        // Every bedtime is 23:00. A one-hour nap at 14:00 shares its night (noon to noon) with
        // that evening's bedtime, so May has three nights and June four.
        let data = try await monthlyTrends { context in
            for month in [5, 6] {
                let days = month == 5 ? [8, 9, 10] : [8, 9, 10, 11]
                for day in days {
                    addSession(starting: start(month: month, day: day, hour: 23, minute: 0), in: context)
                }
                addSession(starting: start(month: month, day: 9, hour: 14, minute: 0), hours: 1, in: context)
            }
        }

        #expect(try point(month: 5, in: data).metrics.startTimeSpread == nil)
        #expect(MonthlyChartSection.accessibilityValue(for: .startTimeSpread, in: data.dataPoints)
                .contains("May 2026: fewer than 4 recorded nights"))

        let june = try #require(try point(month: 6, in: data).metrics.startTimeSpread)
        #expect(june.nights == 4)
        #expect(june.standardDeviation < 1, "The nap was read as a bedtime: \(june.standardDeviation) s")
    }

    @Test("Bedtimes either side of midnight are minutes apart, not a day apart")
    func bedtimeSpreadWrapsAtMidnight() async throws {
        // May alternates 23:50 and 00:10; June alternates 22:50 and 23:10. Both spreads are 20
        // minutes. A 00:10 start belongs to the night before, so each falls on a night of its own.
        let may: [(day: Int, hour: Int, minute: Int)] = [(10, 23, 50), (12, 0, 10), (12, 23, 50), (14, 0, 10)]
        let june: [(day: Int, hour: Int, minute: Int)] = [(10, 22, 50), (11, 23, 10), (12, 22, 50), (13, 23, 10)]
        let data = try await monthlyTrends { context in
            for time in may {
                addSession(starting: start(month: 5, day: time.day, hour: time.hour, minute: time.minute), in: context)
            }
            for time in june {
                addSession(starting: start(month: 6, day: time.day, hour: time.hour, minute: time.minute), in: context)
            }
        }

        let maySpread = try #require(try point(month: 5, in: data).metrics.startTimeSpread)
        let juneSpread = try #require(try point(month: 6, in: data).metrics.startTimeSpread)
        #expect(maySpread.nights == 4 && juneSpread.nights == 4)
        #expect(abs(maySpread.standardDeviation - juneSpread.standardDeviation) < 1,
                "23:50 and 00:10 are 20 minutes apart; \(maySpread.standardDeviation) s vs \(juneSpread.standardDeviation) s")
        #expect(MonthlyChartSection.accessibilityValue(for: .startTimeSpread, in: data.dataPoints)
                .contains("May 2026: varied by about 12 minutes"))
    }

    // MARK: - Chart geometry

    @Test("A chart whose values are all equal plots finite points")
    func flatSeriesPlotsFinitePoints() {
        let values: [(date: Date, value: Double)] = [
            (date: start(month: 4, day: 1, hour: 0, minute: 0), value: 7.5),
            (date: start(month: 5, day: 1, hour: 0, minute: 0), value: 7.5),
            (date: start(month: 6, day: 1, hour: 0, minute: 0), value: 7.5)
        ]
        let points = TrendChart(data: values, valueLabel: "Duration", color: .blue).points

        #expect(points.count == 3)
        #expect(points.allSatisfy { $0.x.isFinite && $0.y.isFinite },
                "Equal values divided by a zero value range: \(points)")
    }
}
