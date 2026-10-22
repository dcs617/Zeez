import CoreData
import Foundation
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

    /// A completed 8-hour Zeez session, with an estimate persisted the way `SleepAnalyzer`
    /// persists one when `estimate` is given.
    @discardableResult
    private func addSession(starting start: Date, estimate: Double? = nil,
                            in context: NSManagedObjectContext) -> SleepSession {
        let session = SleepSession(context: context)
        session.id = UUID()
        session.startTime = start
        session.endTime = start.addingTimeInterval(8 * 3600)
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

    @Test("Months without sessions have no duration, consistency or goal shortfall")
    func emptyMonthsAreUnavailable() async throws {
        let data = try await monthlyTrends { context in
            let preferences = UserPreferences(context: context)
            preferences.id = UUID()
            preferences.sleepGoalEnabled = true
            preferences.targetSleepDuration = 8 * 3600
            addSession(starting: night(month: 6, day: 10), in: context)
        }

        let march = try point(month: 3, in: data)
        #expect(march.metrics.averageDuration == nil)
        #expect(march.consistency == nil, "An empty month used to read as 100% consistent")
        #expect(march.sleepDebt == nil, "An empty month has no shortfall to report, not a shortfall of zero")

        let june = try point(month: 6, in: data)
        let juneDuration = try #require(june.metrics.averageDuration)
        #expect(abs(juneDuration - 8 * 3600) < 1)
        #expect(june.consistency == nil, "Consistency needs at least two sessions")
        #expect(june.sleepDebt == 0, "A recorded 8-hour night meets an 8-hour goal")

        for chart in MonthlyChartSection.ChartType.allCases where chart != .quality {
            #expect(MonthlyChartSection.plottedValues(for: chart, in: data.dataPoints).count <= 1,
                    "\(chart) must not plot the five empty months")
        }
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
}
