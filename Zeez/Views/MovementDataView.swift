import SwiftUI
import os.log

struct MovementDataView: View {
    let session: SleepSession
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                movementChart
                
                movementStats
            }
            .accessibilityIdentifier("movementDataView")
            .padding()
        }
    }
    
    private var movementChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Movement")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("movementChartHeader")
            
            // Chart placeholder
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .frame(height: 200)
                .overlay(
                    Text("Movement Chart")
                        .foregroundColor(.gray)
                )
                .accessibilityLabel("Movement chart for sleep session")
                .accessibilityHint("Shows movement patterns throughout the night")
                .accessibilityIdentifier("movementChartPlaceholder")
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("movementChartSection")
    }
    
    private var movementStats: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistics")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("movementStatsHeader")
            
            let stats = calculateStats()
            LazyVGrid(columns: [.init(), .init()], spacing: 20) {
                MovementStatTile(
                    title: "Activity Level",
                    value: String(format: "%.1f", stats.averageActivity),
                    icon: "figure.walk"
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Activity level: \(String(format: "%.1f", stats.averageActivity))")
                .accessibilityHint("Average movement activity during sleep")
                .accessibilityIdentifier("activityLevelTile")
                
                MovementStatTile(
                    title: "Movement Score",
                    value: "\(Int(stats.score))",
                    icon: "waveform.path"
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Movement score: \(Int(stats.score)) out of 100")
                .accessibilityHint("Overall movement quality rating")
                .accessibilityIdentifier("movementScoreTile")
                
                MovementStatTile(
                    title: "Restlessness",
                    value: "\(stats.restlessEpisodes)",
                    icon: "bed.double"
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Restless episodes: \(stats.restlessEpisodes)")
                .accessibilityHint("Number of high activity periods during sleep")
                .accessibilityIdentifier("restlessnessTile")
                
                MovementStatTile(
                    title: "Peak Activity",
                    value: String(format: "%.1f", stats.peakActivity),
                    icon: "chart.bar.fill"
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Peak activity: \(String(format: "%.1f", stats.peakActivity))")
                .accessibilityHint("Highest movement magnitude recorded")
                .accessibilityIdentifier("peakActivityTile")
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("movementStatsSection")
    }
    
    private func calculateStats() -> (averageActivity: Double, score: Double, restlessEpisodes: Int, peakActivity: Double) {
        guard let movementData = session.movementData?.allObjects as? [MovementData],
              !movementData.isEmpty else {
            return (0, 0, 0, 0)
        }
        
        let activities = movementData.map { Int($0.activityLevel) }
        let magnitudes = movementData.map { $0.magnitude }
        
        let avgActivity = Double(activities.reduce(0, +)) / Double(activities.count)
        let peakActivity = magnitudes.max() ?? 0
        
        // Count episodes where activity level is high
        let restlessThreshold = 3
        let restlessEpisodes = activities.filter { $0 >= restlessThreshold }.count
        
        // Calculate overall score (lower activity is better for sleep)
        let score = 100 - min(100, (avgActivity * 20))
        
        return (avgActivity, score, restlessEpisodes, peakActivity)
    }
}

private struct MovementStatTile: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.purple)
                    .accessibilityHidden(true)
                Text(title)
                    .foregroundColor(.secondary)
            }
            .font(.subheadline)
            
            Text(value)
                .font(.title3)
                .bold()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
        .accessibilityIdentifier("movementStatTile_\(title.lowercased().replacingOccurrences(of: " ", with: ""))")
    }
}

struct MovementDataView_Previews: PreviewProvider {
    static var previews: some View {
        if let session = try? PersistenceController.preview.container.viewContext.fetch(SleepSession.fetchRequest()).first {
            MovementDataView(session: session)
        }
    }
}
