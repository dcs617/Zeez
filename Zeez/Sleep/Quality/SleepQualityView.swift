import SwiftUI

struct SleepQualityView: View {
    let session: SleepSession?
    
    var body: some View {
        ScrollView {
            if let session = session {
                LazyVStack(spacing: 20) {
                    overallScoreSection(session)
                    if session.hasDisplayableScore {
                        metricsSection(session)
                    }
                }
                .padding()
            } else {
                noDataView
            }
        }
        .navigationTitle("Experimental Zeez Estimate")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func overallScoreSection(_ session: SleepSession) -> some View {
        VStack(spacing: 16) {
            if session.hasDisplayableScore {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                        .frame(width: 160, height: 160)

                    Circle()
                        .trim(from: 0, to: session.qualityScore / 100.0)
                        .stroke(Color.blue, lineWidth: 12)
                        .frame(width: 160, height: 160)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: session.qualityScore)

                    VStack {
                        Text("\(Int(session.qualityScore))")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundColor(.blue)

                        Text("EXPERIMENTAL")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Experimental Zeez estimated sleep score: \(Int(session.qualityScore)) points")

                Text(scoreDescription(for: session))
                    .font(.headline)
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "bed.double.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Score Not Available")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("An experimental Zeez estimate appears only when Zeez has sufficient inputs for scoring.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Experimental Zeez estimate not available")
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(UIColor.secondarySystemBackground))
        }
    }
    
    private func metricsSection(_ session: SleepSession) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Supporting Data")
                .font(.headline)
            
            VStack(spacing: 12) {
                supportingDataRow(title: "Recorded Interval", value: formatDuration(session))
                
                supportingDataRow(
                    title: session.hasSourceReportedStages
                        ? "Apple Health-Reported Stage Summary"
                        : "Experimental Zeez Stage Summary",
                    value: stagesSummary(for: session)
                )
            }

            Text("This estimate is not a clinical assessment and should not be used to evaluate a health condition.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(UIColor.secondarySystemBackground))
        }
    }
    
    private func supportingDataRow(title: String, value: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Text(value)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal)
    }
    
    private var noDataView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bed.double.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Sleep Data")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Complete or import a sleep session to view an experimental Zeez estimate when available.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    // MARK: - Helper Methods
    
    private func scoreDescription(for session: SleepSession) -> String {
        "Experimental Zeez Estimate"
    }
    
    private func formatDuration(_ session: SleepSession) -> String {
        guard let duration = session.derivedSleepMetrics.recordedSessionInterval.value else {
            return "Unknown"
        }

        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60

        return "\(hours)h \(minutes)m"
    }
    
    private func stagesSummary(for session: SleepSession) -> String {
        guard let distribution = session.derivedSleepMetrics.asleepStageComposition.value else {
            return "Not available"
        }
        let totalDuration = distribution.values.reduce(0, +)
        guard totalDuration > 0 else { return "No stage data" }
        let deepPercentage = Int((distribution[.deepSleep, default: 0] / totalDuration) * 100)

        return "\(deepPercentage)% Deep Sleep"
    }

}
