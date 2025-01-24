import SwiftUI

struct MovementDataView: View {
    let session: SleepSession
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                movementChart
                
                movementStats
            }
            .padding()
        }
    }
    
    private var movementChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Movement")
                .font(.headline)
            
            // Chart placeholder
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .frame(height: 200)
                .overlay(
                    Text("Movement Chart")
                        .foregroundColor(.gray)
                )
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    private var movementStats: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistics")
                .font(.headline)
            
            let stats = calculateStats()
            LazyVGrid(columns: [.init(), .init()], spacing: 20) {
                MovementStatTile(
                    title: "Activity Level",
                    value: String(format: "%.1f", stats.averageActivity),
                    icon: "figure.walk"
                )
                MovementStatTile(
                    title: "Movement Score",
                    value: "\(Int(stats.score))",
                    icon: "waveform.path"
                )
                MovementStatTile(
                    title: "Restlessness",
                    value: "\(stats.restlessEpisodes)",
                    icon: "bed.double"
                )
                MovementStatTile(
                    title: "Peak Activity",
                    value: String(format: "%.1f", stats.peakActivity),
                    icon: "chart.bar.fill"
                )
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
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
    }
}

struct MovementDataView_Previews: PreviewProvider {
    static var previews: some View {
        if let session = try? PersistenceController.preview.container.viewContext.fetch(SleepSession.fetchRequest()).first {
            MovementDataView(session: session)
        }
    }
}