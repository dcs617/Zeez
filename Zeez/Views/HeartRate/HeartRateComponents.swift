import SwiftUI
import Charts
import os.log

struct HeartRateStatCard: View {
    let title: String
    let value: Int
    var trend: HeartRateTrendDirection?
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.gray)
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(value)")
                    .font(.title2)
                    .bold()
                    .foregroundStyle(color)
                
                Text("BPM")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if let trend = trend {
                    Image(systemName: trend.icon)
                        .foregroundStyle(trend.color)
                        .font(.caption)
                }
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(UIColor.systemBackground))
        }
    }
}

struct HeartRateChart: View {
    let data: [HeartRateDataPoint]
    @Binding var selectedDataPoint: HeartRateDataPoint?
    
    var body: some View {
        Chart {
            ForEach(data) { point in
                LineMark(
                    x: .value("Time", point.date),
                    y: .value("BPM", point.value)
                )
                .foregroundStyle(Color.red.gradient)
                .interpolationMethod(.catmullRom)
                
                AreaMark(
                    x: .value("Time", point.date),
                    y: .value("BPM", point.value)
                )
                .foregroundStyle(Color.red.opacity(0.1))
                .interpolationMethod(.catmullRom)
            }
            
            if let selected = selectedDataPoint {
                RuleMark(x: .value("Time", selected.date))
                    .foregroundStyle(Color.gray.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                
                PointMark(
                    x: .value("Time", selected.date),
                    y: .value("BPM", selected.value)
                )
                .foregroundStyle(.red)
                .annotation(position: .top) {
                    Text("\(Int(selected.value)) BPM")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour())
            }
        }
    }
}

struct HeartRateZoneRow: View {
    let zone: HeartRateZone
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(zone.name)
                    .font(.subheadline)
                
                Text(zone.range)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("\(Int(zone.percentage))%")
                    .font(.subheadline)
                    .bold()
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(zone.color)
                        .frame(width: geometry.size.width * CGFloat(zone.percentage / 100), height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
        }
    }
}

struct SleepStageCorrelationRow: View {
    let stageName: String
    let averageHR: Int
    let timeSpent: TimeInterval
    let color: Color
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(stageName.capitalized)
                .font(.subheadline)
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("\(averageHR) BPM")
                    .font(.subheadline)
                    .bold()
                
                Text(formatDuration(timeSpent))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
