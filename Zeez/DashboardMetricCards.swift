import SwiftUI

struct QualityScoreCard: View {
    let session: SleepSession?
    
    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            Text("Quality Sleep Score")
                .font(.subheadline)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 70, height: 70)
                
                Circle()
                    .trim(from: 0, to: CGFloat((session?.qualityScore ?? 0) / 100))
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 70, height: 70)
                    .rotationEffect(.degrees(-90))
                
                Text("\(Int(session?.qualityScore ?? 0))")
                    .font(.title2)
                    .bold()
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct SleepAverageCard: View {
    let sessions: [SleepSession]
    
    private var averageDuration: TimeInterval {
        let validSessions = sessions.filter { $0.timeInSleep > 0 }
        guard !validSessions.isEmpty else { return 0 }
        return validSessions.reduce(0.0) { $0 + $1.timeInSleep } / Double(validSessions.count)
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            Text("Average Sleep Time")
                .font(.subheadline)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            Text(formatDuration(averageDuration))
                .font(.title2)
                .bold()
            
            Text("hours per day")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = duration / 3600
        return String(format: "%.1f", hours)
    }
}