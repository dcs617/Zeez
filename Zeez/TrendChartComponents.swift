import SwiftUI
import Charts

struct TrendChartComponents {
    struct QualityChart: View {
        let data: [(date: Date, value: Double)]
        let height: CGFloat
        
        var body: some View {
            Chart(data, id: \.date) {
                LineMark(
                    x: .value("Date", $0.date),
                    y: .value("Quality", $0.value)
                )
                .foregroundStyle(Color.purple)
                
                AreaMark(
                    x: .value("Date", $0.date),
                    y: .value("Quality", $0.value)
                )
                .foregroundStyle(Color.purple.opacity(0.1))
            }
            .frame(height: height)
            .chartYAxis {
                AxisMarks(
                    preset: .extended,
                    values: .automatic(desiredCount: 3)
                )
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                }
            }
        }
    }
    
    struct DurationChart: View {
        let data: [(date: Date, value: Double)]
        let height: CGFloat
        
        var body: some View {
            Chart(data, id: \.date) {
                LineMark(
                    x: .value("Date", $0.date),
                    y: .value("Hours", $0.value)
                )
                .foregroundStyle(Color.blue)
                
                AreaMark(
                    x: .value("Date", $0.date),
                    y: .value("Hours", $0.value)
                )
                .foregroundStyle(Color.blue.opacity(0.1))
            }
            .frame(height: height)
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4))
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                }
            }
        }
    }
    
    struct DebtChart: View {
        let data: [(date: Date, value: TimeInterval)]
        let height: CGFloat
        
        var body: some View {
            Chart(data, id: \.date) {
                LineMark(
                    x: .value("Date", $0.date),
                    y: .value("Debt", $0.value / 3600)
                )
                .foregroundStyle(debtColor(for: $0.value))
                
                AreaMark(
                    x: .value("Date", $0.date),
                    y: .value("Debt", $0.value / 3600)
                )
                .foregroundStyle(debtColor(for: $0.value).opacity(0.1))
            }
            .frame(height: height)
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4))
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                }
            }
        }
        
        private func debtColor(for debt: TimeInterval) -> Color {
            switch debt {
            case ..<0: return .green
            case 0..<7200: return .yellow
            default: return .red
            }
        }
    }
    
    struct ScheduleChart: View {
        let data: [(hour: Int, probability: Double)]
        let height: CGFloat
        
        var body: some View {
            Chart(data, id: \.hour) {
                LineMark(
                    x: .value("Hour", $0.hour),
                    y: .value("Probability", $0.probability)
                )
                .foregroundStyle(Color.indigo)
                
                AreaMark(
                    x: .value("Hour", $0.hour),
                    y: .value("Probability", $0.probability)
                )
                .foregroundStyle(Color.indigo.opacity(0.1))
            }
            .frame(height: height)
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 3))
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: 3)) { value in
                    let hour = value.as(Int.self) ?? 0
                    AxisValueLabel("\(hour):00")
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        TrendChartComponents.QualityChart(
            data: [
                (Date().addingTimeInterval(-86400 * 6), 85),
                (Date().addingTimeInterval(-86400 * 5), 75),
                (Date().addingTimeInterval(-86400 * 4), 90),
                (Date().addingTimeInterval(-86400 * 3), 82),
                (Date().addingTimeInterval(-86400 * 2), 88),
                (Date().addingTimeInterval(-86400), 79),
                (Date(), 86)
            ],
            height: 200
        )
        
        TrendChartComponents.DurationChart(
            data: [
                (Date().addingTimeInterval(-86400 * 6), 7.5),
                (Date().addingTimeInterval(-86400 * 5), 6.8),
                (Date().addingTimeInterval(-86400 * 4), 8.2),
                (Date().addingTimeInterval(-86400 * 3), 7.1),
                (Date().addingTimeInterval(-86400 * 2), 7.8),
                (Date().addingTimeInterval(-86400), 6.9),
                (Date(), 7.4)
            ],
            height: 200
        )
    }
    .padding()
}