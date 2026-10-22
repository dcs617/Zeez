import SwiftUI
import os.log

/// Each range must cover a different window. A "Days" range used to sit beside Week,
/// and both were the last 7 days.
enum TrendTimeRange: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"
    
    var id: String { rawValue }
    
    var systemImage: String {
        switch self {
        case .week: return "calendar.badge.clock"
        case .month: return "calendar"
        }
    }
    
    var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
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
