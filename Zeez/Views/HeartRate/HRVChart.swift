import SwiftUI
import Charts
import os.log

struct HRVChart: View {
    let data: [HRVDataPoint]
    @State private var selectedPoint: HRVDataPoint?
    
    private var filteredData: [HRVDataPoint] {
        data.filter { point in
            point.value.isFinite && point.value >= 0 && point.value <= 200
        }
    }
    
    var body: some View {
        if filteredData.isEmpty {
            VStack {
                Text("No HRV data available")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Chart {
                ForEach(filteredData) { point in
                LineMark(
                    x: .value("Time", point.date),
                    y: .value("HRV", point.value)
                )
                .foregroundStyle(Color.purple.gradient)
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 3))
                
                AreaMark(
                    x: .value("Time", point.date),
                    y: .value("HRV", point.value)
                )
                .foregroundStyle(Color.purple.opacity(0.1))
                .interpolationMethod(.monotone)
            }
            
            if let selected = selectedPoint {
                RuleMark(x: .value("Time", selected.date))
                    .foregroundStyle(Color.gray.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                
                PointMark(
                    x: .value("Time", selected.date),
                    y: .value("HRV", selected.value)
                )
                .foregroundStyle(.purple)
                .annotation(position: .top) {
                    Text("\(Int(selected.value)) ms")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.ultraThinMaterial)
                        }
                }
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let val = value.as(Double.self) {
                        Text("\(Int(val))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour())
            }
        }
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    updateSelectedPoint(at: value.location,
                                                     proxy: proxy,
                                                     geometry: geometry)
                                }
                        )
                }
            }
        }
    }
    
    private func updateSelectedPoint(at location: CGPoint,
                                  proxy: ChartProxy,
                                  geometry: GeometryProxy) {
        guard let date = proxy.value(atX: location.x) as Date? else { return }
        
        // Find closest point from filtered data
        let closestPoint = filteredData.min { point1, point2 in
            abs(point1.date.timeIntervalSince(date)) < abs(point2.date.timeIntervalSince(date))
        }
        selectedPoint = closestPoint
    }
}

struct HRVInsightsView: View {
    let averageHRV: Double
    let quality: HRVQuality
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("HRV Insights")
                .font(.headline)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Average")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(Int(averageHRV)) ms")
                        .font(.title2)
                        .bold()
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quality")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(quality.label)
                        .font(.title2)
                        .bold()
                        .foregroundStyle(quality.color)
                }
            }
            
            insightText
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemBackground))
        }
    }
    
    private var insightText: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What this means:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text(insightDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var insightDescription: String {
        switch quality {
        case .excellent:
            "Your heart rate variability is excellent, indicating good cardiovascular health and stress resilience."
        case .good:
            "You have good HRV, suggesting healthy autonomic nervous system function."
        case .fair:
            "Your HRV is fair. Consider stress management techniques to improve it."
        case .poor:
            "Your HRV is lower than ideal. Focus on rest, recovery, and stress reduction."
        }
    }
}

#Preview {
    VStack {
        HRVChart(data: [
            HRVDataPoint(date: Date().addingTimeInterval(-3600), value: 45),
            HRVDataPoint(date: Date().addingTimeInterval(-1800), value: 55),
            HRVDataPoint(date: Date(), value: 50)
        ])
        .frame(height: 200)
        
        HRVInsightsView(averageHRV: 45, quality: .good)
    }
    .padding()
}
