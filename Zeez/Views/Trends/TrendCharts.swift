import SwiftUI
import Charts
import os.log

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
