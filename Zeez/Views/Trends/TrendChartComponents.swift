import SwiftUI
import Charts
import os.log

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
}

#Preview {
    VStack(spacing: 20) {
        TrendChartComponents.QualityChart(
            data: [
                (Date().addingTimeInterval(-AppConstants.Charts.oneDayInSeconds * 6), 85),
                (Date().addingTimeInterval(-AppConstants.Charts.oneDayInSeconds * 5), 75),
                (Date().addingTimeInterval(-AppConstants.Charts.oneDayInSeconds * 4), 90),
                (Date().addingTimeInterval(-AppConstants.Charts.oneDayInSeconds * 3), 82),
                (Date().addingTimeInterval(-AppConstants.Charts.oneDayInSeconds * 2), 88),
                (Date().addingTimeInterval(-AppConstants.Charts.oneDayInSeconds), 79),
                (Date(), 86)
            ],
            height: 200
        )
        
        TrendChartComponents.DurationChart(
            data: [
                (Date().addingTimeInterval(-AppConstants.Charts.oneDayInSeconds * 6), 7.5),
                (Date().addingTimeInterval(-AppConstants.Charts.oneDayInSeconds * 5), 6.8),
                (Date().addingTimeInterval(-AppConstants.Charts.oneDayInSeconds * 4), 8.2),
                (Date().addingTimeInterval(-AppConstants.Charts.oneDayInSeconds * 3), 7.1),
                (Date().addingTimeInterval(-AppConstants.Charts.oneDayInSeconds * 2), 7.8),
                (Date().addingTimeInterval(-AppConstants.Charts.oneDayInSeconds), 6.9),
                (Date(), 7.4)
            ],
            height: 200
        )
    }
    .padding()
}
