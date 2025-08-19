import SwiftUI
import os.log

enum TrendTimeRange: String, CaseIterable, Identifiable {
    case days = "Days"
    case week = "Week"
    case month = "Month"
    
    var id: String { rawValue }
    
    var systemImage: String {
        switch self {
        case .days: return "clock"
        case .week: return "calendar.badge.clock"
        case .month: return "calendar"
        }
    }
    
    var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .days:
            let start = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            return (start, now)
        case .week:
            let start = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
            return (start, now)
        case .month:
            let start = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            return (start, now)
        }
    }
}

struct TimeRangeSelectionView: View {
    @Binding var selectedRange: TrendTimeRange
    
    var body: some View {
        VStack(spacing: 12) {
            Picker("Time Range", selection: $selectedRange) {
                ForEach(TrendTimeRange.allCases) { range in
                    Label(range.rawValue, systemImage: range.systemImage)
                        .tag(range)
                        .accessibilityLabel("\(range.rawValue) time range")
                        .accessibilityIdentifier("timeRange_\(range.rawValue.lowercased())")
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Time range selection")
            .accessibilityHint("Choose time period for data analysis")
            .accessibilityIdentifier("timeRangePicker")
        }
        .padding(.horizontal)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("timeRangeSelectionView")
    }
}

#Preview {
    TimeRangeSelectionView(selectedRange: .constant(.week))
}
