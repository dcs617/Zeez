import SwiftUI
import os.log

struct StageGroup: Identifiable, Hashable {
    let id = UUID()
    let type: String
    let duration: TimeInterval
    let percentage: Double
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: StageGroup, rhs: StageGroup) -> Bool {
        lhs.id == rhs.id
    }
}

struct StageDistributionRow: View {
    let stageType: String
    let percentage: Double
    let duration: TimeInterval
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(stageType.capitalized)
                    .font(.subheadline)
                Spacer()
                Text(String(format: "%.1f%%", percentage))
                    .font(.subheadline)
                    .bold()
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: geometry.size.width, height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(stageColor)
                        .frame(width: geometry.size.width * CGFloat(percentage / 100), height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
            
            Text(formatDuration(duration))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private var stageColor: Color {
        switch stageType.uppercased() {
        case "DEEP": return .indigo
        case "LIGHT": return .blue
        case "REM": return .purple
        case "AWAKE": return .orange
        default: return .gray
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

#Preview {
    VStack(spacing: 16) {
        StageDistributionRow(
            stageType: "DEEP",
            percentage: 25.0,
            duration: 7200
        )
        
        StageDistributionRow(
            stageType: "LIGHT",
            percentage: 45.0,
            duration: 14400
        )
    }
    .padding()
}
