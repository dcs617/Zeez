import SwiftUI
import Charts

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
            }
        }
    }
    
    private var debtTrendChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("30-Day Trend")
                .font(.headline)
            
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
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Total Lost Sleep")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("\(totalDebt, specifier: "%.1f") hours")
                            .font(.headline)
                    }
                }
            } else {
                Text("No historical data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var weeklyBreakdown: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weekly Analysis")
                .font(.headline)
            
            if !history.isEmpty {
                let weeklyData = groupByWeek()
                
                ForEach(weeklyData.sorted(by: { $0.key > $1.key }), id: \.key) { week, debt in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(week)
                            .font(.subheadline)
                        
                        ProgressView(value: min(debt / (recommendedHours * 7), 1))
                            .tint(SleepDebtAnalyzer.shared.getDebtSeverity(debtHours: debt).color)
                        
                        Text("\(debt, specifier: "%.1f") hours of debt")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("No weekly data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var sleepDeficitPatterns: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sleep Deficit Patterns")
                .font(.headline)
            
            let patterns = analyzePatterns()
            if !patterns.isEmpty {
                ForEach(patterns, id: \.self) { pattern in
                    Label(pattern, systemImage: "chart.line.uptrend.xyaxis")
                        .font(.subheadline)
                }
            } else {
                Text("Not enough data to analyze patterns")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
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