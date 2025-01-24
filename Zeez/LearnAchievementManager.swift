import SwiftUI

extension Notification.Name {
    static let learningStreakAchieved = Notification.Name("learningStreakAchieved")
    static let learningCompleted = Notification.Name("learningCompleted")
}

class LearnAchievementManager: ObservableObject {
    static let shared = LearnAchievementManager()
    @Published var currentAchievement: Achievement?
    
    struct Achievement: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let systemImage: String
        let color: Color
    }
    
    private init() {
        setupNotificationObservers()
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: .learningStreakAchieved,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let streak = notification.userInfo?["streak"] as? Int {
                self?.handleStreakAchievement(streak)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .learningCompleted,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleCompletionAchievement()
        }
    }
    
    private func handleStreakAchievement(_ streak: Int) {
        let achievement = Achievement(
            title: "\(streak) Day Streak!",
            message: "You've been learning for \(streak) days straight",
            systemImage: "flame.fill",
            color: .orange
        )
        showAchievement(achievement)
    }
    
    private func handleCompletionAchievement() {
        let achievement = Achievement(
            title: "Learning Complete!",
            message: "You've mastered all available content",
            systemImage: "star.fill",
            color: .yellow
        )
        showAchievement(achievement)
    }
    
    private func showAchievement(_ achievement: Achievement) {
        withAnimation {
            currentAchievement = achievement
        }
        
        // Automatically dismiss after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            withAnimation {
                self?.currentAchievement = nil
            }
        }
    }
}

struct LearnAchievementOverlay: ViewModifier {
    @StateObject private var achievementManager = LearnAchievementManager.shared
    
    func body(content: Content) -> some View {
        content.overlay(
            ZStack(alignment: .top) {
                if let achievement = achievementManager.currentAchievement {
                    LearnAchievementNotification(
                        title: achievement.title,
                        message: achievement.message,
                        systemImage: achievement.systemImage,
                        color: achievement.color
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding()
                }
            }
            .animation(.spring(), value: achievementManager.currentAchievement != nil)
        )
    }
}

extension View {
    func achievementOverlay() -> some View {
        modifier(LearnAchievementOverlay())
    }
}