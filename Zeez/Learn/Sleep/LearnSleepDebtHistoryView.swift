import SwiftUI
import Charts
import os.log

struct LearnSleepDebtHistoryView: View {
    let history: [(Date, Double)]
    let recommendedHours: Double
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                debtTrendChart
                
                weeklyBreakdown
                
                sleepDeficitPatterns
            }
            .padding()
        }
        .navigationTitle("Sleep Debt History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }
                .accessibilityLabel("Close sleep debt history")
                .accessibilityHint("Return to sleep debt overview")
                .accessibilityIdentifier("closeSleepDebtHistoryButton")
            }
        }
    }
    
    private var debtTrendChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("30-Day Trend")
                .font(.headline)
                .accessibilityLabel("30-day trend section")
            
            // Here we could add a line chart showing the history
            // For now, showing a summary
            if !history.isEmpty {
                let totalDebt = history.map { $0.1 }.reduce(0, +)
                let avgDebt = totalDebt / Double(history.count)
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Average Debt")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("\(avgDebt, specifier: "%.1f") hours")
                            .font(.headline)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Average debt: \(avgDebt, specifier: "%.1f") hours")
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Total Lost Sleep")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("\(totalDebt, specifier: "%.1f") hours")
                            .font(.headline)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Total lost sleep: \(totalDebt, specifier: "%.1f") hours")
                }
            } else {
                Text("No historical data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .accessibilityLabel("No historical sleep debt data available")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("debtTrendSection")
    }
    
    private var weeklyBreakdown: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weekly Analysis")
                .font(.headline)
                .accessibilityLabel("Weekly analysis section")
            
            if !history.isEmpty {
                let weeklyData = groupByWeek()
                
                ForEach(weeklyData.sorted(by: { $0.key > $1.key }), id: \.key) { week, debt in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(week)
                            .font(.subheadline)
                        
                        ProgressView(value: min(debt / (recommendedHours * 7), 1))
                            .tint(getDebtSeverity(debtHours: debt).color)
                            .accessibilityLabel("Sleep debt progress for week \(week)")
                        
                        Text("\(debt, specifier: "%.1f") hours of debt")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Week \(week): \(debt, specifier: "%.1f") hours of sleep debt")
                }
            } else {
                Text("No weekly data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .accessibilityLabel("No weekly sleep debt data available")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("weeklyBreakdownSection")
    }
    
    private var sleepDeficitPatterns: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sleep Deficit Patterns")
                .font(.headline)
                .accessibilityLabel("Sleep deficit patterns section")
            
            let patterns = analyzePatterns()
            if !patterns.isEmpty {
                ForEach(patterns, id: \.self) { pattern in
                    Label(pattern, systemImage: "chart.line.uptrend.xyaxis")
                        .font(.subheadline)
                        .accessibilityLabel("Pattern: \(pattern)")
                }
            } else {
                Text("Not enough data to analyze patterns")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .accessibilityLabel("Not enough data to analyze sleep patterns")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("sleepDeficitPatternsSection")
    }
    
    private func groupByWeek() -> [String: Double] {
        var weeklyData: [String: Double] = [:]
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        for (date, debt) in history {
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
            let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)!
            let weekKey = "\(formatter.string(from: weekStart)) - \(formatter.string(from: weekEnd))"
            weeklyData[weekKey, default: 0] += debt
        }
        
        return weeklyData
    }
    
    private func analyzePatterns() -> [String] {
        guard !history.isEmpty else { return [] }
        
        var patterns: [String] = []
        let debts = history.map { $0.1 }
        let weekday = history.map { Calendar.current.component(.weekday, from: $0.0) }
        
        // Weekend vs Weekday analysis
        let weekendDebts = zip(weekday, debts).filter { $0.0 == 1 || $0.0 == 7 }.map { $0.1 }
        let weekdayDebts = zip(weekday, debts).filter { $0.0 != 1 && $0.0 != 7 }.map { $0.1 }
        
        if !weekendDebts.isEmpty && !weekdayDebts.isEmpty {
            let avgWeekendDebt = weekendDebts.reduce(0, +) / Double(weekendDebts.count)
            let avgWeekdayDebt = weekdayDebts.reduce(0, +) / Double(weekdayDebts.count)
            
            if avgWeekendDebt < avgWeekdayDebt {
                patterns.append("Better sleep on weekends")
            } else if avgWeekendDebt > avgWeekdayDebt {
                patterns.append("Better sleep during weekdays")
            }
        }
        
        // Trend analysis
        let firstWeekAvg = debts.prefix(7).reduce(0, +) / Double(min(7, debts.count))
        let lastWeekAvg = debts.suffix(7).reduce(0, +) / Double(min(7, debts.count))
        
        if lastWeekAvg < firstWeekAvg {
            patterns.append("Improving sleep debt trend")
        } else if lastWeekAvg > firstWeekAvg {
            patterns.append("Increasing sleep debt trend")
        }
        
        return patterns
    }
    
    private func getDebtSeverity(debtHours: Double) -> DebtSeverity {
        if debtHours <= 2 {
            return .minimal
        } else if debtHours <= 5 {
            return .moderate
        } else if debtHours <= 10 {
            return .significant
        } else {
            return .severe
        }
    }
}

#Preview {
    let sampleData: [(Date, Double)] = [
        (Date(), 8.5),
        (Date().addingTimeInterval(-86400), 7.2),
        (Date().addingTimeInterval(-172800), 6.8)
    ]
    
    return NavigationView {
        LearnSleepDebtHistoryView(history: sampleData, recommendedHours: 8.0)
    }
}
