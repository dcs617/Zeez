import SwiftUI
import os.log

struct MonthlyChartSection: View {
    let dataPoints: [MonthlyDataPoint]
    @Binding var selectedDataPoint: MonthlyDataPoint?
    @State private var selectedChart: ChartType = .quality
    
    enum ChartType: String, CaseIterable {
        case quality = "Experimental Zeez Estimate"
        case duration = "Duration"
        case consistency = "Consistency"
        case sleepDebt = "Goal Shortfall"

        var color: Color {
            switch self {
            case .quality, .duration: return .blue
            case .consistency: return .green
            case .sleepDebt: return .orange
            }
        }

        /// Announced before the per-month values, so the experimental label reaches
        /// VoiceOver along with the numbers (claims rule 10).
        var accessibilityLabel: String {
            switch self {
            case .quality: return "Experimental Zeez estimate, monthly average"
            case .duration: return "Duration, monthly average"
            case .consistency: return "Sleep schedule consistency by month"
            case .sleepDebt: return "Sleep goal shortfall by month"
            }
        }

        /// Shown in place of the chart when no month has a value.
        var unavailableText: String {
            switch self {
            case .quality: return "No experimental Zeez estimates in these months"
            case .duration: return "No recorded sessions in these months"
            case .consistency: return "Not enough sessions to show consistency"
            case .sleepDebt: return "No sleep goal shortfall to show for these months"
            }
        }

        fileprivate var monthUnavailableText: String {
            switch self {
            case .quality: return "no estimate"
            case .duration: return "no recorded sessions"
            case .consistency: return "not enough sessions"
            case .sleepDebt: return "not available"
            }
        }

        fileprivate func spokenValue(_ value: Double) -> String {
            switch self {
            case .quality: return "\(Int(value.rounded())) out of 100"
            case .duration: return String(format: "%.1f hours", value)
            case .consistency: return "\(Int(value.rounded())) percent"
            case .sleepDebt: return String(format: "%.1f hours below your selected goal", value)
            }
        }

        /// The value `point` contributes to this chart, or `nil` when the month has none.
        fileprivate func value(of point: MonthlyDataPoint) -> Double? {
            switch self {
            case .quality: return point.metrics.averageQuality
            case .duration: return point.metrics.averageDuration.map { $0 / 3600 }
            case .consistency: return point.consistency
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
                Text("Average of nights with an experimental Zeez estimate. Months without one are not plotted.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
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
                TrendChart(data: values, valueLabel: chart.rawValue, color: chart.color)
                    .frame(height: 200)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(chart.accessibilityLabel)
        .accessibilityValue(Self.accessibilityValue(for: chart, in: dataPoints))
        .accessibilityIdentifier("monthlyChart")
    }
    
    private func point(_ sleepDebt: TimeInterval) -> Color {
        sleepDebt > 14400 ? .red : .orange
    }
    
    private func updateSelection(
        at location: CGPoint,
        proxy: GeometryProxy,
        geometry: GeometryProxy
    ) {
        let xPosition = location.x - geometry.size.width
        let width = geometry.size.width
        let percentage = xPosition / width
        
        let index = Int(percentage * CGFloat(dataPoints.count))
        if index >= 0 && index < dataPoints.count {
            selectedDataPoint = dataPoints[index]
        }
    }
}
