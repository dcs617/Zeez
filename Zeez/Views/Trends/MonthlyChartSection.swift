import SwiftUI
import os.log

struct MonthlyChartSection: View {
    let dataPoints: [MonthlyDataPoint]
    @Binding var selectedDataPoint: MonthlyDataPoint?
    @State private var selectedChart: ChartType = .quality
    
    enum ChartType: String, CaseIterable {
        case quality = "Estimated Score"
        case duration = "Duration"
        case consistency = "Consistency"
        case sleepDebt = "Goal Shortfall"
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
            }
            
            switch selectedChart {
            case .quality:
                qualityChart
            case .duration:
                durationChart
            case .consistency:
                consistencyChart
            case .sleepDebt:
                sleepDebtChart
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private var qualityChart: some View {
        TrendChart(
            data: dataPoints.map { point in
                (date: point.month, value: point.metrics.averageQuality)
            },
            valueLabel: "Score",
            color: .blue
        )
        .frame(height: 200)
    }
    
    private var durationChart: some View {
        TrendChart(
            data: dataPoints.map { point in
                (date: point.month, value: point.metrics.averageDuration / 3600)
            },
            valueLabel: "Hours",
            color: .blue
        )
        .frame(height: 200)
    }
    
    private var consistencyChart: some View {
        TrendChart(
            data: dataPoints.map { point in
                (date: point.month, value: point.consistency)
            },
            valueLabel: "Consistency %",
            color: .green
        )
        .frame(height: 200)
    }
    
    private var sleepDebtChart: some View {
        TrendChart(
            data: dataPoints.map { point in
                (date: point.month, value: point.sleepDebt / 3600)
            },
            valueLabel: "Hours",
            color: .orange // Or use a more sophisticated color choice, see below
        )
        .frame(height: 200)
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
