import SwiftUI
import os.log

struct SummaryCard: View {
    let icon: String
    let title: String
    let hasData: Bool
    let session: SleepSession?
    let previewStat: PreviewStat?
    var educationalLink: AnyView? = nil
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            // Icon with colored background
            ZStack {
                Circle()
                    .fill(iconBackgroundColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(iconBackgroundColor)
            }
            
            // Title and stat
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Group {
                    if !hasData {
                        Text("No data")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if let stat = previewStat {
                        StatPreview(stat: stat)
                    }
                }
            }
            
            Spacer(minLength: 8)
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var iconBackgroundColor: Color {
        switch icon {
        case "chart.bar.fill": return .blue
        case "heart.fill": return .red
        case "moon.zzz.fill": return .indigo
        case "waveform.path.ecg": return .purple
        default: return .blue
        }
    }
}

struct StatPreview: View {
    let stat: PreviewStat
    
    var body: some View {
        HStack(spacing: 4) {
            Text(stat.label)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            Text(stat.value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(1)
        }
    }
}

struct PreviewStat {
    let label: String
    let value: String
}

// MARK: - Preview Stats Providers

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
        
        let stats = [
            PreviewStat(label: "Avg", value: "\(Int(avg)) bpm"),
            PreviewStat(label: "Max", value: "\(Int(max)) bpm"),
            PreviewStat(label: "Min", value: "\(Int(min)) bpm")
        ]
        
        return stats.randomElement()
    }
}

struct SleepQualityPreviewStats {
    static func getRandomStat(from session: SleepSession) -> PreviewStat? {
        guard session.hasDisplayableScore else {
            return PreviewStat(label: "Score", value: "Unavailable")
        }
        
        return PreviewStat(label: "Experimental Zeez Estimate", value: "\(Int(session.qualityScore)) pts")
    }
}

struct SleepStagesPreviewStats {
    static func getRandomStat(from session: SleepSession) -> PreviewStat? {
        guard let distribution = session.derivedSleepMetrics.asleepStageComposition.value else {
            return nil
        }
        let totalTime = distribution.values.reduce(0, +)
        guard totalTime > 0 else { return nil }
        let deepSleepTime = distribution[.deepSleep, default: 0]
        let remSleepTime = distribution[.rem, default: 0]

        let deepPercentage = totalTime > 0 ? (deepSleepTime / totalTime) * 100 : 0
        let remPercentage = totalTime > 0 ? (remSleepTime / totalTime) * 100 : 0

        return deepSleepTime > 0
            ? PreviewStat(label: "Deep", value: "\(Int(deepPercentage))%")
            : PreviewStat(label: "REM", value: "\(Int(remPercentage))%")
    }
}

struct SleepInfoPreviewStats {
    static func getRandomStat(from session: SleepSession) -> PreviewStat? {
        guard let startTime = session.startTime,
              let endTime = session.endTime,
              let duration = session.derivedSleepMetrics.recordedSessionInterval.value else {
            return nil
        }

        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        let stats = [
            PreviewStat(label: "Duration", value: "\(hours)h \(minutes)m"),
            PreviewStat(label: "Bedtime", value: formatter.string(from: startTime)),
            PreviewStat(label: "Wake", value: formatter.string(from: endTime))
        ]
        
        return stats.randomElement()
    }
}

#Preview {
    VStack(spacing: 12) {
        SummaryCard(
            icon: "heart.fill",
            title: "Heart Rate",
            hasData: true,
            session: nil,
            previewStat: PreviewStat(label: "Avg", value: "68 bpm")
        )
        
        SummaryCard(
            icon: "moon.zzz.fill",
            title: "Sleep Quality",
            hasData: false,
            session: nil,
            previewStat: nil
        )
        
        SummaryCard(
            icon: "waveform.path.ecg",
            title: "Sleep Stages",
            hasData: true,
            session: nil,
            previewStat: PreviewStat(label: "Cycles", value: "4")
        )
    }
    .padding()
    .background(Color(UIColor.systemBackground))
}
