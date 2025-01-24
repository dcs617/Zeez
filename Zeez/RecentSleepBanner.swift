import SwiftUI
import CoreData

struct RecentSleepBanner: View {
    let session: SleepSession?
    
    var body: some View {
        NavigationLink(destination: RecentSessionsView()) {
            HStack {
                HStack(spacing: 12) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                    
                    VStack(alignment: .leading) {
                        Text("Recent Sleep")
                            .font(.headline)
                        
                        if let session = session,
                           let startTime = session.startTime,
                           let endTime = session.endTime {
                            Text("\(startTime.formatted(.dateTime.month().day())) • \(formatDuration(from: startTime, to: endTime))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private func formatDuration(from start: Date, to end: Date) -> String {
        let duration = end.timeIntervalSince(start)
        let hours = Int(duration) / 3600
        let minutes = Int(duration.truncatingRemainder(dividingBy: 3600)) / 60
        return String(format: "%dh %02dm", hours, minutes)
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let session = SleepSession(context: context)
    session.startTime = Date().addingTimeInterval(-8 * 3600)
    session.endTime = Date()
    session.qualityScore = 85.5
    
    return RecentSleepBanner(session: session)
        .padding()
}
