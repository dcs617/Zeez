import SwiftUI
import Charts
import os.log

struct MonthlyChartSection: View {
    let dataPoints: [MonthlyDataPoint]
    @State private var selectedChart: ChartType = .quality
    
    enum ChartType: String, CaseIterable {
        case quality = "Experimental Zeez Estimate"
        case duration = "Recorded Session Duration"
        case startTimeSpread = "Start Time Spread"
        case sleepDebt = "Goal Shortfall"

        var color: Color {
            switch self {
            case .quality, .duration: return .blue
            case .startTimeSpread: return .green
            case .sleepDebt: return .orange
            }
        }

        /// The value axis's unit, shown beside it.
        var unitLabel: String {
            switch self {
            case .quality: return "out of 100"
            case .duration, .sleepDebt: return "hours"
            case .startTimeSpread: return "minutes"
            }
        }

        /// Announced before the per-month values, so the experimental label reaches
        /// VoiceOver along with the numbers (claims rule 10).
        var accessibilityLabel: String {
            switch self {
            case .quality: return "Experimental Zeez estimate, monthly average"
            case .duration: return "Recorded session duration, monthly average"
            case .startTimeSpread: return "Recorded sleep start time spread by month"
            case .sleepDebt: return "Sleep goal shortfall by month"
            }
        }

        /// Shown in place of the chart when no month has a value.
        var unavailableText: String {
            switch self {
            case .quality: return "No experimental Zeez estimates in these months"
            case .duration: return "No recorded sessions in these months"
            case .startTimeSpread: return "Needs at least \(SleepStartSpread.minimumNights) recorded nights in a month"
            case .sleepDebt: return "No sleep goal shortfall to show for these months"
            }
        }

        fileprivate var monthUnavailableText: String {
            switch self {
            case .quality: return "no estimate"
            case .duration: return "no recorded sessions"
            case .startTimeSpread: return "fewer than \(SleepStartSpread.minimumNights) recorded nights"
            case .sleepDebt: return "not available"
            }
        }

        fileprivate func spokenValue(_ value: Double) -> String {
            switch self {
            case .quality: return "\(Int(value.rounded())) out of 100"
            case .duration: return String(format: "%.1f hours", value)
            case .startTimeSpread: return "varied by about \(Int(value.rounded())) minutes"
            case .sleepDebt: return String(format: "%.1f hours below your selected goal", value)
            }
        }

        /// The value `point` contributes to this chart, or `nil` when the month has none.
        fileprivate func value(of point: MonthlyDataPoint) -> Double? {
            switch self {
            case .quality: return point.metrics.averageQuality
            case .duration: return point.metrics.averageRecordedDuration.map { $0 / 3600 }
            case .startTimeSpread: return point.metrics.startTimeSpread.map { $0.standardDeviation / 60 }
            case .sleepDebt: return point.sleepDebt.map { $0 / 3600 }
            }
        }
    }

    /// The months that have a value for `chart`. A month without one is left out, never
    /// plotted as zero (claims rule 4).
    static func plottedValues(for chart: ChartType, in dataPoints: [MonthlyDataPoint]) -> [(date: Date, value: Double)] {
        dataPoints.compactMap { point in
            chart.value(of: point).map { (date: point.month, value: $0) }
        }
    }

    /// The value axis for `chart`. Scaling it to the months' own lowest and highest values drew a
    /// two-point change in the estimate across the whole chart, a trend the numbers do not make.
    /// The estimate keeps its full 0–100 scale; every other measure starts at zero.
    static func valueDomain(for chart: ChartType, values: [Double]) -> ClosedRange<Double> {
        switch chart {
        case .quality:
            return 0...100
        case .duration, .startTimeSpread, .sleepDebt:
            return 0...max((values.max() ?? 0) * 1.15, 1)
        }
    }

    /// Every month in the window, including the ones the chart leaves out, so VoiceOver
    /// hears that a month had no value rather than skipping it silently.
    static func accessibilityValue(for chart: ChartType, in dataPoints: [MonthlyDataPoint]) -> String {
        guard !plottedValues(for: chart, in: dataPoints).isEmpty else { return chart.unavailableText }
        let monthStyle = Date.FormatStyle().month(.wide).year()
        return dataPoints.map { point in
            let month = point.month.formatted(monthStyle)
            return "\(month): " + (chart.value(of: point).map(chart.spokenValue) ?? chart.monthUnavailableText)
        }
        .joined(separator: "; ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Monthly Trends")
                    .font(.headline)

                Spacer()

                Picker("Chart Type", selection: $selectedChart) {
                    ForEach(ChartType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .accessibilityLabel("Chart type")
                .accessibilityHint("Choose which monthly measure the chart shows")
            }

            chart(for: selectedChart)

            if selectedChart == .quality {
                Text("Average of nights with an experimental Zeez estimate from the current calculation. Months without one are not plotted.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if selectedChart == .startTimeSpread {
                Text("Minutes, as the standard deviation of each night's recorded sleep start time. Months with fewer than \(SleepStartSpread.minimumNights) recorded nights are not plotted.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    private func chart(for chart: ChartType) -> some View {
        let values = Self.plottedValues(for: chart, in: dataPoints)
        return Group {
            if values.count < 2 {
                Text(values.isEmpty ? chart.unavailableText : "Not enough months with data to chart yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 200)
            } else {
                Chart(values, id: \.date) { month in
                    LineMark(
                        x: .value("Month", month.date, unit: .month),
                        y: .value(chart.rawValue, month.value)
                    )
                    .foregroundStyle(chart.color)
                    PointMark(
                        x: .value("Month", month.date, unit: .month),
                        y: .value(chart.rawValue, month.value)
                    )
                    .foregroundStyle(chart.color)
                }
                .chartYScale(domain: Self.valueDomain(for: chart, values: values.map(\.value)))
                .chartYAxisLabel(chart.unitLabel)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated))
                    }
                }
                .frame(height: 200)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(chart.accessibilityLabel)
        .accessibilityValue(Self.accessibilityValue(for: chart, in: dataPoints))
        .accessibilityIdentifier("monthlyChart")
    }
}
