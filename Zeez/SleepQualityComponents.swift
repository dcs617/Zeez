import SwiftUI
import Charts

struct QualityScoreRing: View {
    let score: Double
    let size: CGFloat
    let lineWidth: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: lineWidth)
                .frame(width: size, height: size)
            
            Circle()
                .trim(from: 0, to: score / 100)
                .stroke(
                    scoreColor.gradient,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
            
            VStack(spacing: 4) {
                Text("\(Int(score))")
                    .font(.system(size: size * 0.25, weight: .bold))
                Text(qualityLabel)
                    .font(.system(size: size * 0.12))
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var scoreColor: Color {
        switch score {
        case 90...: return .green
        case 70..<90: return .blue
        case 50..<70: return .yellow
        default: return .red
        }
    }
    
    private var qualityLabel: String {
        switch score {
        case 90...: return "Excellent"
        case 70..<90: return "Good"
        case 50..<70: return "Fair"
        default: return "Poor"
        }
    }
}

struct QualityMetricCard: View {
    let title: String
    let score: Double
    let icon: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(metricColor)
                
                Text(title)
                    .font(.headline)
                
                Spacer()
                
                Text("\(Int(score))%")
                    .font(.title3)
                    .bold()
                    .foregroundStyle(metricColor)
            }
            
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .fill(metricColor.gradient)
                        .frame(width: geometry.size.width * CGFloat(score / 100), height: 6)
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemBackground))
        }
    }
    
    private var metricColor: Color {
        switch score {
        case 90...: return .green
        case 70..<90: return .blue
        case 50..<70: return .yellow
        default: return .red
        }
    }
}

struct SleepQualityChart: View {
    let data: [(Date, Double)]
    @Binding var selectedDate: Date?
    private let calendar = Calendar.current
    
    var body: some View {
        Group {
            if data.isEmpty {
                emptyDataView
            } else {
                chartView
            }
        }
    }
    
    private var emptyDataView: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.downtrend.xyaxis")
                .font(.system(size: 24))
                .foregroundStyle(.secondary)
            Text("No data available")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var chartView: some View {
        Chart {
            ForEach(data.indices, id: \.self) { index in
                LineMark(
                    x: .value("Date", data[index].0),
                    y: .value("Score", data[index].1)
                )
                .foregroundStyle(Color.blue.gradient)
                .interpolationMethod(.catmullRom)
                
                AreaMark(
                    x: .value("Date", data[index].0),
                    y: .value("Score", data[index].1)
                )
                .foregroundStyle(Color.blue.opacity(0.1))
                .interpolationMethod(.catmullRom)
            }
            
            // Only show the selection if we have both a selected date and matching data
            if let selectedDate = selectedDate,
               let selectedPoint = data.first(where: { calendar.isDate($0.0, inSameDayAs: selectedDate) }) {
                RuleMark(x: .value("Selected", selectedPoint.0))
                    .foregroundStyle(.gray.opacity(0.3))
                
                PointMark(
                    x: .value("Selected", selectedPoint.0),
                    y: .value("Score", selectedPoint.1)
                )
                .foregroundStyle(.blue)
                .annotation(position: .top) {
                    Text("\(Int(selectedPoint.1))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                }
            }
        }
        .chartYScale(domain: 0...100)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                if let score = value.as(Double.self) {
                    AxisValueLabel {
                        Text("\(Int(score))")
                            .font(.caption)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                AxisGridLine()
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        Text(date.formatted(.dateTime.weekday(.short)))
                            .font(.caption)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                updateSelectedDate(at: value.location,
                                                proxy: proxy,
                                                geometry: geometry)
                            }
                    )
            }
        }
    }
    
    private func updateSelectedDate(at location: CGPoint,
                                 proxy: ChartProxy,
                                 geometry: GeometryProxy) {
        guard !data.isEmpty else { return }
        
        // Convert the touch location to a date value
        guard let date = proxy.value(atX: location.x, as: Date.self) else { return }
        
        // Find the closest date in our data set
        let closestPoint = data.min { first, second in
            abs(first.0.timeIntervalSince(date)) < abs(second.0.timeIntervalSince(date))
        }
        
        selectedDate = closestPoint?.0
    }
}