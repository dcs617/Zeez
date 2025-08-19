import SwiftUI
import os.log

struct QualityScoreCard: View {
    let session: SleepSession?
    
    private var qualityScore: Double {
        session?.qualityScore ?? 0
    }
    
    private var qualityScoreEntity: SleepQualityScore? {
        session?.qualityScores?.allObjects.first as? SleepQualityScore
    }
    
    private var scoreColor: Color {
        switch qualityScore {
        case 0..<50: return .red
        case 50..<70: return .orange
        case 70..<85: return .yellow
        default: return .green
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Quality Score")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                if let scoreEntity = qualityScoreEntity, scoreEntity.isPersonalized {
                    Image(systemName: "person.fill")
                        .foregroundStyle(.purple)
                        .font(.caption)
                        .accessibilityLabel("Personalized analysis")
                }
                
                Spacer()
            }
            
            Spacer()
            
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: 8)
                    .frame(width: 70, height: 70)
                
                // Progress circle
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
                
                // Score text
                VStack(spacing: 0) {
                    Text("\(Int(qualityScore))")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("pts")
                        .font(.caption2)
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
}

struct SleepAverageCard: View {
    let sessions: [SleepSession]
    
    private var averageDuration: TimeInterval {
        let validSessions = sessions.filter { $0.timeInSleep > 0 }
        guard !validSessions.isEmpty else { return 0 }
        return validSessions.reduce(0.0) { $0 + $1.timeInSleep } / Double(validSessions.count)
    }
    
    private var averageColor: Color {
        let hours = averageDuration / 3600
        switch hours {
        case 0..<6: return .red
        case 6..<7: return .orange
        case 7..<8: return .yellow
        default: return .green
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Average Sleep")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Spacer()
            
            VStack(spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(formatDuration(averageDuration))
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .foregroundColor(averageColor)
                    
                    Text("h")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(.secondary)
                }
                
                Text("hours/day")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
