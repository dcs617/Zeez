import Foundation
import Testing
@testable import Zeez

/// The weekly Trends charts.
///
/// "Sleep Schedule" (`ScheduleConsistencyChart`) draws a night as a bar from its recorded start
/// to its recorded end. On a midnight-to-midnight axis a 23:00–07:00 night was drawn from 23:00
/// back up to 07:00, across the sixteen hours the person was awake.
struct TrendsChartTests {

    private func date(day: Int, hour: Int, minute: Int = 0) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 6, day: day, hour: hour, minute: minute))!
    }

    @Test("A night from 23:00 to 07:00 spans the eight hours slept")
    func overnightBarSpansTheNight() {
        let span = ScheduleConsistencyChart.span(bedtime: date(day: 9, hour: 23), wakeTime: date(day: 10, hour: 7))

        #expect(span.end - span.start == 8, "The bar ran from \(span.start) to \(span.end)")
        #expect(span.start == 11, "23:00 is eleven hours after noon")
    }

    @Test("A night after midnight and an afternoon nap sit on the same noon-to-noon axis")
    func spansShareOneAxis() {
        let afterMidnight = ScheduleConsistencyChart.span(bedtime: date(day: 10, hour: 0, minute: 30),
                                                          wakeTime: date(day: 10, hour: 8))
        #expect(afterMidnight.start == 12.5 && afterMidnight.end == 20)

        let nap = ScheduleConsistencyChart.span(bedtime: date(day: 10, hour: 14), wakeTime: date(day: 10, hour: 15))
        #expect(nap.start == 2 && nap.end == 3)

        // A recording across noon continues past the axis end rather than wrapping to the top.
        let acrossNoon = ScheduleConsistencyChart.span(bedtime: date(day: 10, hour: 10), wakeTime: date(day: 10, hour: 13))
        #expect(acrossNoon.start == 22 && acrossNoon.end == 25)
    }

    @Test("A month's time axis is labelled weekly, a week's daily")
    func monthAxisIsLabelledWeekly() {
        // Labelling each of a month's 30 days with its weekday printed overlapping labels.
        #expect(TrendChartComponents.axisStride(for: .week) == 1)
        #expect(TrendChartComponents.axisStride(for: .month) == 7)
    }
}
