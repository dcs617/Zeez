import SwiftUI
import os.log

struct LastNightCard: View {
    let session: SleepSession
    
    var body: some View {
        NavigationLink(destination: EnhancedSleepDetailsView(session: session)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Last Night's Sleep")
                        .font(.headline)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                }
                
                if let startTime = session.startTime,
                   let endTime = session.endTime {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(startTime, formatter: FormatterUtils.timeFormatter)
                            Image(systemName: "arrow.right")
                                .foregroundColor(.secondary)
                            Text(endTime, formatter: FormatterUtils.timeFormatter)
                        }
                        
                        Text("Duration: \(FormatterUtils.formattedDuration(start: startTime, end: endTime))")
                        
                        HStack(spacing: 16) {
                            // Sleep Score
                            VStack(alignment: .leading) {
                                Text("Sleep Score")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Text("\(Int(session.qualityScore))")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.purple)
                            }
                            
                            // Quality Indicator
                            qualityIndicator(score: session.qualityScore)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(15)
            .shadow(radius: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }

    
    private func qualityIndicator(score: Double) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 8)
                
                // Score indicator
                RoundedRectangle(cornerRadius: 4)
                    .fill(scoreColor(score))
                    .frame(width: geometry.size.width * CGFloat(score / 100), height: 8)
            }
        }
        .frame(height: 8)
        .padding(.vertical, 8)
    }
    
    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .blue
        case 40..<60: return .yellow
        default: return .red
        }
    }
    
    private func analyzeSleepQuality() async {
        guard let context = session.managedObjectContext else { return }
        
        let analyzer = SleepQualityAnalyzer(context: context, session: session)
        do {
            let qualityScore = try await analyzer.analyzeSleepQuality()
            session.qualityScore = qualityScore.overallScore
            try context.save()
        } catch {
            ZeezLogger.error(ZeezLogger.sleepTracking, "Error analyzing sleep quality", error: error)
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let session = SleepSession(context: context)
    session.startTime = Date().addingTimeInterval(-28800) // 8 hours ago
    session.endTime = Date()
    session.qualityScore = 85
    
    return LastNightCard(session: session)
        .padding()
        .background(Color(.systemGray6))
}
