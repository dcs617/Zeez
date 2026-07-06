import SwiftUI
import os.log

struct QualityScoreCard: View {
    let session: SleepSession?

    private var qualityScore: Double {
        session?.qualityScore ?? 0
    }

    private var hasDisplayableScore: Bool {
        session?.hasDisplayableScore == true
    }

    private var scoreProvenance: String {
        guard hasDisplayableScore else { return "" }
        return "Experimental"
    }

    private var scoreColor: Color {
        .blue
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Zeez Estimate")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if !scoreProvenance.isEmpty {
                    Text(scoreProvenance)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.gray.opacity(0.15))
                        .clipShape(Capsule())
                        .accessibilityLabel("Score source: \(scoreProvenance)")
                }

                Spacer()
            }

            Spacer()

            if hasDisplayableScore {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.15), lineWidth: 8)
                        .frame(width: 70, height: 70)

                    Circle()
                        .trim(from: 0, to: CGFloat(qualityScore / 100))
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [scoreColor.opacity(0.8), scoreColor]),
                                center: .center,
                                startAngle: .degrees(0),
                                endAngle: .degrees(360 * qualityScore / 100)
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: qualityScore)

                    VStack(spacing: 0) {
                        Text("\(Int(qualityScore))")
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)

                        Text("pts")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .accessibilityLabel("Experimental Zeez estimated sleep score: \(Int(qualityScore)) points")
            } else {
                VStack(spacing: 4) {
                    Text("–")
                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                    Text("No score")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel("Experimental Zeez estimate not available")
            }

            Spacer()
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct SleepAverageCard: View {
    let sessions: [SleepSession]
    
    private var averageDuration: TimeInterval? {
        let durations = sessions.compactMap { $0.derivedSleepMetrics.recordedSessionInterval.value }
        guard !durations.isEmpty else { return nil }
        return durations.reduce(0, +) / Double(durations.count)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Avg. Session")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Spacer()
            
            VStack(spacing: 4) {
                if let averageDuration {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(formatDuration(averageDuration))
                            .font(.system(size: 32, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)

                        Text("h")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundColor(.secondary)
                    }

                    Text("duration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("--")
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                    Text("No duration data")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = duration / 3600
        return String(format: "%.1f", hours)
    }
}

#Preview {
    HStack(spacing: 16) {
        SleepAverageCard(sessions: [])
            .frame(width: 170, height: 170)
        
        QualityScoreCard(session: nil)
            .frame(width: 170, height: 170)
    }
    .padding()
    .background(Color(UIColor.systemBackground))
}
