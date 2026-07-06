import SwiftUI
import CoreData

struct SleepStageView: View {
    @ObservedObject var session: SleepSession
    
    private var sortedStages: [SleepStage] {
        let stages = session.sleepStages?.allObjects as? [SleepStage] ?? []
        return stages.sorted { ($0.startTime ?? Date()) < ($1.startTime ?? Date()) }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if !sortedStages.isEmpty {
                    stageDistributionSection
                    stageTimelineSection
                } else {
                    noStageDataView
                }
            }
            .padding()
        }
        .navigationTitle("Sleep Stages")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var stageDistributionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stage Distribution")
                .font(.headline)

            Text(session.stageSourceDescription)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let distribution = calculateDistribution() {
                VStack(spacing: 8) {
                    ForEach(SleepStageType.allCases.filter { distribution[$0] != nil }, id: \.self) { stageType in
                        let percentage = distribution[stageType] ?? 0

                        HStack {
                            Circle()
                                .fill(stageColor(for: stageType.rawValue))
                                .frame(width: 12, height: 12)

                            Text(stageType.displayName(reportedByAppleHealth: session.hasSourceReportedStages))
                                .font(.subheadline)

                            Spacer()

                            Text("\(Int(percentage))%")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                    }
                }
            } else {
                Text(session.hasSourceReportedStages
                     ? "Reported asleep-stage composition is not available for this session."
                     : "Experimental Zeez stage composition is not available for this session.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(UIColor.secondarySystemBackground))
        }
    }
    
    private var stageTimelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stage Timeline")
                .font(.headline)
            
            VStack(spacing: 4) {
                ForEach(sortedStages, id: \.id) { stage in
                    stageTimelineRow(for: stage)
                }
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(UIColor.secondarySystemBackground))
        }
    }
    
    private func stageTimelineRow(for stage: SleepStage) -> some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(stageColor(for: stage.stageType ?? ""))
                .frame(width: 4)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 2) {
                Text(stageDisplayName(for: stage.stageType ?? ""))
                    .font(.subheadline.weight(.medium))

                if let startTime = stage.startTime {
                    Text(formatTime(startTime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text("Duration: \(formatDuration(stage.duration))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .frame(height: 60)
        .padding(.horizontal)
    }
    
    private var noStageDataView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bed.double")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Stage Data")
                .font(.title2)
                .fontWeight(.medium)

            Text("Stage data will appear here when Apple Health reports it or Zeez has sufficient inputs for an experimental estimate.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Helper Methods

    private func calculateDistribution() -> [SleepStageType: Double]? {
        guard let durations = session.derivedSleepMetrics.asleepStageComposition.value else {
            return nil
        }
        let totalDuration = durations.values.reduce(0, +)
        guard totalDuration > 0 else { return nil }

        return durations.mapValues { ($0 / totalDuration) * 100 }
    }

    private func stageColor(for type: String) -> Color {
        switch type.lowercased() {
        case "deep": return .indigo
        case "light": return .blue
        case "asleepunspecified", "asleep_unspecified": return .teal
        case "rem": return .purple
        case "awake": return .orange
        default: return .gray
        }
    }
    
    private func stageDisplayName(for type: String) -> String {
        if let stageType = SleepStageType.normalize(type) {
            return stageType.displayName(reportedByAppleHealth: session.hasSourceReportedStages)
        }
        switch type.lowercased() {
        case "inbed": return "In Bed (Context)"
        default: return "Unknown"
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
