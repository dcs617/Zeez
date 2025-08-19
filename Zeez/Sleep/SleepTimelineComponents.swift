import SwiftUI
import Charts
import os.log

struct SleepTimelineView: View {
    let session: SleepSession
    let previousSessions: [SleepSession]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleep Timeline")
                .font(.headline)
            
            timelineChart
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(UIColor.secondarySystemBackground))
        }
    }
    
    private var timelineChart: some View {
        Chart {
            ForEach(allSessions) { session in
                if let start = session.startTime,
                   let end = session.endTime {
                    BarMark(
                        x: .value("Day", start, unit: .day),
                        yStart: .value("Start", start.timeIntervalSince1970),
                        yEnd: .value("End", end.timeIntervalSince1970),
                        width: .fixed(20)
                    )
                    .foregroundStyle(session.id == self.session.id ? Color.blue : Color.gray.opacity(0.5))
                }
            }
        }
        .frame(height: 150)
        .chartYAxis {
            AxisMarks(values: .stride(by: AppConstants.SleepCycle.chartAxisStride)) { value in
                if let timeInterval = value.as(Double.self) {
                    let date = Date(timeIntervalSince1970: timeInterval)
                    AxisValueLabel {
                        Text(date.formatted(.dateTime.hour()))
                            .font(.caption)
                    }
                }
            }
        }
    }
    
    private var allSessions: [SleepSession] {
        (previousSessions + [session]).sorted { $0.startTime ?? Date() < $1.startTime ?? Date() }
    }
}
