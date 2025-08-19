import SwiftUI
import os.log

struct LearnAchievementNotification: View {
    let title: String
    let message: String
    let systemImage: String
    let color: Color
    
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundColor(color)
                .padding(12)
                .background(
                    Circle()
                        .fill(color.opacity(0.2))
                )
                .scaleEffect(isAnimating ? 1 : 0.8)
                .blur(radius: isAnimating ? 0 : 5)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .opacity(isAnimating ? 1 : 0)
            .offset(x: isAnimating ? 0 : 20)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                isAnimating = true
            }
        }
    }
}

#Preview {
    VStack {
        LearnAchievementNotification(
            title: "5 Day Streak!",
            message: "You've been learning about sleep for 5 days in a row",
            systemImage: "star.fill",
            color: .yellow
        )
        
        LearnAchievementNotification(
            title: "Quiz Master",
            message: "You've completed all quizzes in the Sleep Basics path",
            systemImage: "graduationcap.fill",
            color: .blue
        )
    }
    .padding()
}
