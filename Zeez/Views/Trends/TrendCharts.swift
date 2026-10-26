import SwiftUI
import Charts
import os.log

/// Line chart for displaying trend data
struct TrendChart: View {
    let data: [(date: Date, value: Double)]
    let valueLabel: String
    let color: Color
    
    /// Each point scaled to 0...1 on both axes. An axis whose values are all equal has no
    /// range to divide by, so its points sit at the middle rather than at NaN.
    var points: [CGPoint] {
        guard !data.isEmpty,
              let minDate = data.map({ $0.date }).min(),
              let maxDate = data.map({ $0.date }).max(),
              let minValue = data.map({ $0.value }).min(),
              let maxValue = data.map({ $0.value }).max()
        else { return [] }
        
        let dateRange = maxDate.timeIntervalSince(minDate)
        let valueRange = maxValue - minValue
        
        return data.map { item in
            let x = dateRange > 0 ? item.date.timeIntervalSince(minDate) / dateRange : 0.5
            let y = valueRange > 0 ? (item.value - minValue) / valueRange : 0.5
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

/// Each recorded night as a bar from its start to its end, on a noon-to-noon axis so a night
/// is one unbroken bar. A midnight-to-midnight axis drew a 23:00–07:00 night from 23:00 back up
/// to 07:00, across the hours awake, and divided by zero with a single night.
struct ScheduleConsistencyChart: View {
    let data: [(date: Date, bedtime: Date, wakeTime: Date)]

    private struct Night: Identifiable {
        let id: Int
        let night: Date
        let bedtime: Date
        let wakeTime: Date
        let start: Double
        let end: Double
    }

    private var nights: [Night] {
        data.enumerated().map { index, item in
            let span = Self.span(bedtime: item.bedtime, wakeTime: item.wakeTime)
            return Night(
                id: index,
                night: NightCoverage.nightKey(for: item.bedtime, calendar: .current),
                bedtime: item.bedtime,
                wakeTime: item.wakeTime,
                start: span.start,
                end: span.end
            )
        }
    }

    var body: some View {
        if data.isEmpty {
            Text("No recorded sessions in this period")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Chart(nights) { night in
                BarMark(
                    x: .value("Night", night.night, unit: .day),
                    yStart: .value("Recorded start", night.start),
                    yEnd: .value("Recorded end", night.end),
                    width: .ratio(0.5)
                )
                .foregroundStyle(Color.indigo)
                .cornerRadius(4)
                .accessibilityLabel(Text(night.night.formatted(.dateTime.weekday(.wide).month().day())))
                .accessibilityValue(Text("Recorded from \(Self.clockTime(night.bedtime)) to \(Self.clockTime(night.wakeTime))"))
            }
            .chartYScale(domain: .automatic(includesZero: false, reversed: true))
            .chartYAxis {
                AxisMarks(values: .stride(by: 3)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let hours = value.as(Double.self) {
                            Text(Self.clockLabel(hoursAfterNoon: hours))
                        }
                    }
                }
            }
        }
    }

    /// A night's bar in hours after noon: 23:00 is 11 and 07:00 the next morning is 19. The end
    /// is the start plus the recorded duration, so a bar never wraps.
    static func span(bedtime: Date, wakeTime: Date, calendar: Calendar = .current) -> (start: Double, end: Double) {
        let components = calendar.dateComponents([.hour, .minute], from: bedtime)
        let clock = Double(components.hour ?? 0) + Double(components.minute ?? 0) / 60
        let start = (clock + 12).truncatingRemainder(dividingBy: 24)
        return (start, start + wakeTime.timeIntervalSince(bedtime) / 3600)
    }

    private static func clockLabel(hoursAfterNoon hours: Double) -> String {
        let hour = ((Int(hours.rounded()) + 12) % 24 + 24) % 24
        return String(format: "%02d:00", hour)
    }

    private static func clockTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}
