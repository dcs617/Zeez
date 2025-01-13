import SwiftUI

/// Line chart for displaying trend data
struct TrendChart: View {
    let data: [(date: Date, value: Double)]
    let valueLabel: String
    let color: Color
    
    private var points: [CGPoint] {
        guard !data.isEmpty,
              let minDate = data.map({ $0.date }).min(),
              let maxDate = data.map({ $0.date }).max(),
              let minValue = data.map({ $0.value }).min(),
              let maxValue = data.map({ $0.value }).max()
        else { return [] }
        
        let dateRange = maxDate.timeIntervalSince(minDate)
        let valueRange = maxValue - minValue
        
        return data.map { item in
            let x = item.date.timeIntervalSince(minDate) / dateRange
            let y = (item.value - minValue) / valueRange
            return CGPoint(x: x, y: y)
        }
    }
    
    var body: some View {
        VStack {
            GeometryReader { geometry in
                if points.count > 1 {
                    Path { path in
                        path.move(to: convert(point: points[0], in: geometry))
                        
                        for point in points.dropFirst() {
                            path.addLine(to: convert(point: point, in: geometry))
                        }
                    }
                    .stroke(color, lineWidth: 2)
                    
                    // Data points
                    ForEach(0..<points.count, id: \.self) { index in
                        Circle()
                            .fill(color)
                            .frame(width: 6, height: 6)
                            .position(convert(point: points[index], in: geometry))
                    }
                }
            }
            
            // X-axis labels
            HStack {
                ForEach(0..<3) { i in
                    if let date = data[safe: i * (data.count - 1) / 2]?.date {
                        Text(FormatterUtils.shortDateFormatter.string(from: date))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    private func convert(point: CGPoint, in geometry: GeometryProxy) -> CGPoint {
        CGPoint(
            x: point.x * geometry.size.width,
            y: (1 - point.y) * geometry.size.height
        )
    }
}

/// Chart showing sleep schedule consistency
struct ScheduleConsistencyChart: View {
    let data: [(date: Date, bedtime: Date, wakeTime: Date)]
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                ZStack {
                    // Time range background
                    ForEach(0..<24) { hour in
                        let y = CGFloat(hour) / 24 * geometry.size.height
                        
                        Text(String(format: "%02d:00", hour))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .position(x: 20, y: y)
                        
                        Path { path in
                            path.move(to: CGPoint(x: 40, y: y))
                            path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                        }
                        .stroke(Color.gray.opacity(0.2))
                    }
                    
                    // Sleep periods
                    ForEach(data.indices, id: \.self) { index in
                        let item = data[index]
                        let x = CGFloat(index) / CGFloat(data.count - 1) * 
                              (geometry.size.width - 50) + 40
                        
                        // Bedtime point
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 6, height: 6)
                            .position(
                                x: x,
                                y: timeToY(item.bedtime, in: geometry)
                            )
                        
                        // Wake time point
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 6, height: 6)
                            .position(
                                x: x,
                                y: timeToY(item.wakeTime, in: geometry)
                            )
                        
                        // Connection line
                        Path { path in
                            path.move(to: CGPoint(
                                x: x,
                                y: timeToY(item.bedtime, in: geometry)
                            ))
                            path.addLine(to: CGPoint(
                                x: x,
                                y: timeToY(item.wakeTime, in: geometry)
                            ))
                        }
                        .stroke(Color.purple.opacity(0.5))
                    }
                }
                
                // Date labels
                HStack {
                    ForEach(0..<3) { i in
                        if let date = data[safe: i * (data.count - 1) / 2]?.date {
                            Text(FormatterUtils.shortDateFormatter.string(from: date))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
    
    private func timeToY(_ date: Date, in geometry: GeometryProxy) -> CGFloat {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hour = Double(components.hour ?? 0)
        let minute = Double(components.minute ?? 0)
        let time = hour + minute / 60
        return CGFloat(time / 24) * geometry.size.height
    }
}

extension Collection {
    /// Safe array access that returns nil if index is out of bounds
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
