import SwiftUI
import Charts

struct SleepInformationView: View {
    let session: SleepSession?
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingTips = false
    
    var body: some View {
        ScrollView {
            if let session = session {
                VStack(spacing: 20) {
                    durationSection(session)
                    sleepTimesSection(session)
                    sleepEfficiencySection(session)
                    timeBreakdownSection(session)
                }
                .padding()
            } else {
                noDataView
            }
        }
        .navigationTitle("Sleep Information")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button {
                showingTips = true
            } label: {
                Image(systemName: "info.circle")
            }
        }
        .sheet(isPresented: $showingTips) {
            SleepInfoGuideView()
        }
    }
    
    private var noDataView: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 44))
                .foregroundStyle(.blue)
            
            Text("No Sleep Data Available")
                .font(.headline)
            
            Text("Track your sleep to see detailed sleep information and trends.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private func durationSection(_ session: SleepSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleep Duration")
                .font(.headline)
            
            HStack(spacing: 20) {
                CircularProgressView(
                    value: timeInSleepHours(session),
                    total: 8,
                    lineWidth: 12,
                    size: 120
                )
                
                VStack(alignment: .leading, spacing: 8) {
                    MetricRow(
                        label: "Total Sleep",
                        value: formatDuration(session.timeInSleep)
                    )
                    
                    MetricRow(
                        label: "Time in Bed",
                        value: formatDuration(timeInBed(session))
                    )
                    
                    MetricRow(
                        label: "Sleep Goal",
                        value: "8h 00m"
                    )
                }
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(UIColor.secondarySystemBackground))
        }
    }
    
    private func sleepTimesSection(_ session: SleepSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleep Times")
                .font(.headline)
            
            VStack(spacing: 16) {
                TimeRow(
                    icon: "moon.fill",
                    label: "Bedtime",
                    time: session.startTime ?? Date()
                )
                
                TimeRow(
                    icon: "sun.max.fill",
                    label: "Wake Time",
                    time: session.endTime ?? Date()
                )
                
                if let startTime = session.startTime,
                   let endTime = session.endTime {
                    TimeRow(
                        icon: "clock.fill",
                        label: "Duration",
                        value: formatDuration(endTime.timeIntervalSince(startTime))
                    )
                }
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(UIColor.secondarySystemBackground))
        }
    }
    
    private func sleepEfficiencySection(_ session: SleepSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleep Efficiency")
                .font(.headline)
            
            let efficiency = calculateEfficiency(session)
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(Int(efficiency))%")
                        .font(.title)
                        .bold()
                    Text(efficiencyRating(efficiency))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                CircularProgressView(
                    value: efficiency,
                    total: 100,
                    lineWidth: 8,
                    size: 60
                )
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(UIColor.secondarySystemBackground))
        }
    }
    
    private func timeBreakdownSection(_ session: SleepSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Time Breakdown")
                .font(.headline)
            
            VStack(spacing: 16) {
                TimeBreakdownRow(
                    label: "Deep Sleep",
                    duration: timeInStage(session, stage: "DEEP"),
                    total: session.timeInSleep
                )
                
                TimeBreakdownRow(
                    label: "Light Sleep",
                    duration: timeInStage(session, stage: "LIGHT"),
                    total: session.timeInSleep
                )
                
                TimeBreakdownRow(
                    label: "REM Sleep",
                    duration: timeInStage(session, stage: "REM"),
                    total: session.timeInSleep
                )
                
                TimeBreakdownRow(
                    label: "Time Awake",
                    duration: timeInStage(session, stage: "AWAKE"),
                    total: session.timeInSleep
                )
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(UIColor.secondarySystemBackground))
        }
    }
    
    // MARK: - Helper Functions
    
    private func timeInSleepHours(_ session: SleepSession) -> Double {
        session.timeInSleep / 3600
    }
    
    private func timeInBed(_ session: SleepSession) -> TimeInterval {
        guard let start = session.startTime,
              let end = session.endTime else { return 0 }
        return end.timeIntervalSince(start)
    }
    
    private func calculateEfficiency(_ session: SleepSession) -> Double {
        let bedTime = timeInBed(session)
        guard bedTime > 0 else { return 0 }
        return (session.timeInSleep / bedTime) * 100
    }
    
    private func timeInStage(_ session: SleepSession, stage: String) -> TimeInterval {
        guard let stages = session.sleepStages?.allObjects as? [SleepStage] else { return 0 }
        return stages
            .filter { $0.stageType == stage }
            .reduce(0) { $0 + $1.duration }
    }
    
    private func efficiencyRating(_ efficiency: Double) -> String {
        switch efficiency {
        case 90...100: return "Excellent"
        case 80..<90: return "Good"
        case 70..<80: return "Fair"
        default: return "Poor"
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - Supporting Views

struct CircularProgressView: View {
    let value: Double
    let total: Double
    let lineWidth: CGFloat
    let size: CGFloat
    
    private var progress: Double {
        min(max(value / total, 0), 1)
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: lineWidth)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color.blue.gradient,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
            
            VStack {
                if total == 100 {
                    Text("\(Int(value))%")
                        .font(.title3)
                        .bold()
                } else {
                    Text(String(format: "%.1f", value))
                        .font(.title3)
                        .bold()
                    Text("hrs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
    }
}

struct MetricRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .bold()
        }
    }
}

struct TimeRow: View {
    let icon: String
    let label: String
    var time: Date? = nil
    var value: String? = nil
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)
            
            Text(label)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            if let time = time {
                Text(time.formatted(date: .omitted, time: .shortened))
                    .bold()
            } else if let value = value {
                Text(value)
                    .bold()
            }
        }
    }
}

struct TimeBreakdownRow: View {
    let label: String
    let duration: TimeInterval
    let total: TimeInterval
    
    private var percentage: Double {
        guard total > 0 else { return 0 }
        return (duration / total) * 100
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(label)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatDuration(duration))
                    .bold()
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * CGFloat(percentage / 100), height: 6)
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)
            
            Text("\(Int(percentage))%")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

#Preview {
    NavigationView {
        SleepInformationView(session: nil)
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
