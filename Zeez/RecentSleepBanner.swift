import SwiftUI
import CoreData
import os.log

struct RecentSleepBanner: View {
    let session: SleepSession?
    
    var body: some View {
        NavigationLink(destination: RecentSessionsView()) {
            HStack(spacing: 16) {
                // Icon with gradient background
                ZStack {
                    LinearGradient(
                        colors: [Color.blue.opacity(0.8), Color.indigo.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: 48, height: 48)
                    .cornerRadius(12)
                    
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent Sleep Sessions")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if let session = session,
                       let startTime = session.startTime,
                       let endTime = session.endTime {
                        HStack(spacing: 4) {
                            Text(startTime.formatted(.dateTime.month(.abbreviated).day()))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Text("•")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            
                            Text(formatDuration(from: startTime, to: endTime))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                            
                            if session.qualityScore > 0 {
                                Text("•")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                
                                HStack(spacing: 2) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 10))
                                        .foregroundColor(qualityColor(for: session.qualityScore))
                                    
                                    Text("\(Int(session.qualityScore))")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } else {
                        Text("View all sessions")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(Color(UIColor.tertiarySystemFill))
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.tertiarySystemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatDuration(from start: Date, to end: Date) -> String {
        let duration = end.timeIntervalSince(start)
        let hours = Int(duration) / 3600
        let minutes = Int(duration.truncatingRemainder(dividingBy: 3600)) / 60
        return String(format: "%dh %02dm", hours, minutes)
    }
    
    private func qualityColor(for score: Double) -> Color {
        switch score {
        case 0..<50: return .red
        case 50..<70: return .orange
        case 70..<85: return .yellow
        default: return .green
        }
    }
}

#Preview {
    NavigationView {
        VStack(spacing: 16) {
            // With session data
            RecentSleepBanner(session: createMockSession())
            
            // Without session data
            RecentSleepBanner(session: nil)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
    }
}

// Helper function for preview
private func createMockSession() -> SleepSession? {
    let context = PersistenceController.preview.container.viewContext
    let session = SleepSession(context: context)
    session.startTime = Date().addingTimeInterval(-AppConstants.Sleep.targetDuration)
    session.endTime = Date()
    session.qualityScore = 85.5
    return session
}
