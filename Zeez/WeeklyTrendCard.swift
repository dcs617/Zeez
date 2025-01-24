import SwiftUI
import Charts

struct WeeklyTrendCard: View {
    let sessions: [SleepSession]
    
    private var weeklyAverage: Double {
        let validSessions = sessions.filter { $0.qualityScore > 0 }
        guard !validSessions.isEmpty else { return 0 }
        return validSessions.reduce(0.0) { $0 + $1.qualityScore } / Double(validSessions.count)
    }
    
    private var weeklyConsistency: Double {
        guard sessions.count > 1 else { return 100 }
        let bedtimes = sessions.compactMap { $0.startTime?.timeIntervalSince1970 }
        let waketimes = sessions.compactMap { $0.endTime?.timeIntervalSince1970 }
        
        guard !bedtimes.isEmpty, !waketimes.isEmpty else { return 0 }
        
        // Calculate variance in bedtimes and waketimes
        let bedtimeVariance = calculateVariance(bedtimes)
        let waketimeVariance = calculateVariance(waketimes)
        
        // Convert variance to consistency score (lower variance = higher consistency)
        let maxVariance: Double = 3600 * 2 // 2 hours variance = 0% consistency
        let bedtimeConsistency = max(0, 100 - (bedtimeVariance / maxVariance * 100))
        let waketimeConsistency = max(0, 100 - (waketimeVariance / maxVariance * 100))
        
        return (bedtimeConsistency + waketimeConsistency) / 2
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Weekly Overview")
                    .font(.headline)
                
                Spacer()
                
                NavigationLink(destination: TrendsView()) {
                    Text("See More")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            
            // Quality Score Chart
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Quality Trend")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("Avg: \(Int(weeklyAverage))")
                        .font(.subheadline)
                        .foregroundColor(.purple)
                }

                Chart {
                    ForEach(sessions, id: \.id) { session in
                        LineMark(
                            x: .value("Day", session.startTime ?? Date(), unit: .day),
                            y: .value("Quality", session.qualityScore)
                        )
                        .foregroundStyle(.purple)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisValueLabel(format: .dateTime.weekday(.short))
                    }
                }
                .chartYScale(domain: 0...100)                    .frame(height: 100)
            }
            
            Divider()
            
            // Weekly Metrics
            HStack(spacing: 20) {
                // Sleep Consistency
                VStack(alignment: .leading) {
                    Text("Consistency")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(weeklyConsistency))%")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(consistencyColor)
                }
                
                Divider()
                
                // Average Duration
                VStack(alignment: .leading) {
                    Text("Avg Duration")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(averageDurationFormatted)
                        .font(.title3)
                        .fontWeight(.semibold)
                }
            }
            
            // Progress indicators
            HStack(spacing: 12) {
                ForEach(sessions.prefix(7).reversed(), id: \.id) { session in
                    DayIndicator(session: session)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(15)
        .shadow(radius: 2)
    }
    
    private var consistencyColor: Color {
        switch weeklyConsistency {
        case 80...100: return .green
        case 60..<80: return .blue
        case 40..<60: return .yellow
        default: return .red
        }
    }
    
    private var averageDurationFormatted: String {
        let totalDuration = sessions.map { $0.timeInSleep }.reduce(0, +)
        let averageDuration = totalDuration / Double(max(sessions.count, 1))
        let hours = Int(averageDuration / 3600)
        let minutes = Int((averageDuration.truncatingRemainder(dividingBy: 3600)) / 60)
        return "\(hours)h \(minutes)m"
    }
    
    private func calculateVariance(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDifferences = values.map { pow($0 - mean, 2) }
        return squaredDifferences.reduce(0, +) / Double(values.count)
    }
}

struct DayIndicator: View {
    let session: SleepSession
    
    private var qualityColor: Color {
        let score = session.qualityScore
        switch score {
        case 80...100: return .green
        case 60..<80: return .blue
        case 40..<60: return .yellow
        default: return .red
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(qualityColor)
                .frame(width: 8, height: 8)
            
            Text(session.startTime?.formatted(.dateTime.weekday(.abbreviated)) ?? "")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    NavigationView {
        WeeklyTrendCard(sessions: [])
            .padding()
    }
}
