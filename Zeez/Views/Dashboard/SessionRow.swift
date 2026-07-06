import SwiftUI
import os.log

struct SessionRow: View {
    let session: SleepSession
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                // Date and Duration
                HStack {
                    Text(session.startTime ?? Date(), style: .date)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    if session.startTime != nil,
                       let duration = session.derivedSleepMetrics.recordedSessionInterval.value {
                        Text(formatDuration(duration))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Sleep Quality and Details
                HStack(spacing: 12) {
                    if session.hasDisplayableScore {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.blue)
                            Text(String(format: "Exp. Zeez %.0f", session.qualityScore))
                        }
                    }

                    if let startTime = session.startTime {
                        Text(startTime, style: .time)
                            .foregroundColor(.secondary)
                        Text("→")
                            .foregroundColor(.secondary)
                        if let endTime = session.endTime {
                            Text(endTime, style: .time)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 8)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration.truncatingRemainder(dividingBy: 3600)) / 60
        return String(format: "%dh %02dm", hours, minutes)
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let session = SleepSession(context: context)
    session.startTime = Date().addingTimeInterval(-AppConstants.Sleep.targetDuration) // 8 hours ago
    session.endTime = Date()
    session.qualityScore = 85.5
    
    return SessionRow(session: session)
        .padding()
}
