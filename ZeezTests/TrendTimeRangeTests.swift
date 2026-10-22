import Foundation
import Testing
@testable import Zeez

/// The Trends time-range picker (`TrendTimeRange`).
struct TrendTimeRangeTests {

    /// Window lengths in whole days, so the separate `Date()` reads inside `dateRange`
    /// cannot tell two ranges apart or order them by accident.
    private var lengthsInDays: [Int] {
        TrendTimeRange.allCases.map { range in
            let window = range.dateRange
            return Int((window.end.timeIntervalSince(window.start) / 86_400).rounded())
        }
    }

    @Test("Every time range covers a different window")
    func rangesAreDistinct() {
        let lengths = lengthsInDays
        #expect(Set(lengths).count == lengths.count,
                "Two segments showing the same window offer a choice that changes nothing: \(lengths)")
    }

    @Test("Ranges end now and get longer from left to right")
    func rangesAreOrdered() {
        for window in TrendTimeRange.allCases.map(\.dateRange) {
            #expect(abs(window.end.timeIntervalSinceNow) < 60)
        }
        #expect(lengthsInDays == lengthsInDays.sorted())
    }
}
