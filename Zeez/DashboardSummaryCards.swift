import SwiftUI

struct SummaryCard: View {
    let icon: String
    let title: String
    let hasData: Bool
    let session: SleepSession?
    let previewStat: PreviewStat?
    var educationalLink: AnyView? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.headline)
                
                Spacer()
                
                if !hasData {
                    Text("No data for selected date")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                } else if let stat = previewStat {
                    StatPreview(stat: stat)
                }
            }
            
            if let link = educationalLink {
                Divider()
                link
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct StatPreview: View {
    let stat: PreviewStat
    
    var body: some View {
        HStack(spacing: 4) {
            Text(stat.label)
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Text(stat.value)
                .font(.subheadline)
                .bold()
                .foregroundColor(.primary)
        }
    }
}

struct PreviewStat {
    let label: String
    let value: String
}

struct HeartRatePreviewStats {
    static func getRandomStat(from session: SleepSession) -> PreviewStat? {
        guard let heartRateData = session.heartRateData?.allObjects as? [HeartRateData],
              !heartRateData.isEmpty else {
            return nil
        }
        
        let values = heartRateData.map { $0.value }
        let avg = values.reduce(0, +) / Double(values.count)
        let max = values.max() ?? 0
        let min = values.min() ?? 0
        
        // Calculate HRV (simplified for example)
        let hrv = values.enumerated().dropFirst().map { index, value -> Double in
            let previous = values[index - 1]
            return abs(value - previous)
        }.reduce(0, +) / Double(values.count - 1)
        
        let stats = [
            PreviewStat(label: "Avg", value: "\(Int(avg)) bpm"),
            PreviewStat(label: "Max", value: "\(Int(max)) bpm"),
            PreviewStat(label: "Min", value: "\(Int(min)) bpm"),
            PreviewStat(label: "HRV", value: "\(Int(hrv)) ms")
        ]
        
        return stats.randomElement()
    }
}

struct SleepQualityPreviewStats {
    static func getRandomStat(from session: SleepSession) -> PreviewStat? {
        guard let qualityScore = session.qualityScores?.allObjects as? [SleepQualityScore],
              !qualityScore.isEmpty else {
            return nil
        }
        
        let score = session.qualityScore
        let efficiency = (session.timeInSleep / (session.endTime?.timeIntervalSince(session.startTime ?? Date()) ?? 1)) * 100
        
        let stats = [
            PreviewStat(label: "Score", value: "\(Int(score))%"),
            PreviewStat(label: "Efficiency", value: "\(Int(efficiency))%")
        ]
        
        return stats.randomElement()
    }
}

struct SleepCyclesPreviewStats {
    static func getRandomStat(from session: SleepSession) -> PreviewStat? {
        guard let stages = session.sleepStages?.allObjects as? [SleepStage],
              !stages.isEmpty else {
            return nil
        }
        
        let totalTime = stages.reduce(0) { $0 + $1.duration }
        let deepSleepTime = stages.filter { $0.stageType == "DEEP" }.reduce(0) { $0 + $1.duration }
        let remSleepTime = stages.filter { $0.stageType == "REM" }.reduce(0) { $0 + $1.duration }
        
        let deepPercentage = (deepSleepTime / totalTime) * 100
        let remPercentage = (remSleepTime / totalTime) * 100
        
        let stats = [
            PreviewStat(label: "Deep", value: "\(Int(deepPercentage))%"),
            PreviewStat(label: "REM", value: "\(Int(remPercentage))%"),
            PreviewStat(label: "Cycles", value: "\(stages.count)")
        ]
        
        return stats.randomElement()
    }
}

struct SleepInfoPreviewStats {
    static func getRandomStat(from session: SleepSession) -> PreviewStat? {
        guard let startTime = session.startTime,
              let endTime = session.endTime else {
            return nil
        }
        
        let duration = endTime.timeIntervalSince(startTime)
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        
        let stats = [
            PreviewStat(label: "Duration", value: "\(hours)h \(minutes)m"),
            PreviewStat(label: "Start", value: startTime.formatted(.dateTime.hour().minute())),
            PreviewStat(label: "End", value: endTime.formatted(.dateTime.hour().minute()))
        ]
        
        return stats.randomElement()
    }
}

// MARK: - Extensions
#Preview {
    VStack {
        SummaryCard(
            icon: "heart.fill",
            title: "Heart Rate",
            hasData: true,
            session: nil,
            previewStat: PreviewStat(label: "Avg", value: "68 bpm"),
            educationalLink: AnyView(
                Label("Learn About Heart Rate", systemImage: "book.fill")
                    .font(.caption)
                    .foregroundColor(.blue)
            )
        )
        
        SummaryCard(
            icon: "moon.fill",
            title: "Sleep Quality",
            hasData: false,
            session: nil,
            previewStat: nil
        )
    }
    .padding()
}
