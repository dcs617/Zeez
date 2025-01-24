import SwiftUI

struct RecommendationRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        RecommendationRow(
            icon: "moon.circle.fill",
            title: "Sleep Duration",
            description: "Try to get at least 7 hours of sleep for optimal rest",
            color: .blue
        )
        
        RecommendationRow(
            icon: "star.fill",
            title: "Keep it up!",
            description: "You're maintaining good sleep habits",
            color: .green
        )
    }
    .padding()
}
