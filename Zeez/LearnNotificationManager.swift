import UserNotifications
import CoreData

class LearnNotificationManager {
    static let shared = LearnNotificationManager()
    
    private let notificationCenter = UNUserNotificationCenter.current()
    private let challengeCategory = "com.zeez.notifications.challenge"
    private let learningCategory = "com.zeez.notifications.learning"
    
    private init() {
        setupNotificationCategories()
    }
    
    // MARK: - Setup
    
    private func setupNotificationCategories() {
        let markCompleteAction = UNNotificationAction(
            identifier: "MARK_COMPLETE",
            title: "Mark Complete",
            options: .foreground
        )
        
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE",
            title: "Remind Later",
            options: .foreground
        )
        
        let viewAction = UNNotificationAction(
            identifier: "VIEW",
            title: "View",
            options: .foreground
        )
        
        let challengeCategory = UNNotificationCategory(
            identifier: self.challengeCategory,
            actions: [markCompleteAction, snoozeAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        
        let learningCategory = UNNotificationCategory(
            identifier: self.learningCategory,
            actions: [viewAction, snoozeAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        
        notificationCenter.setNotificationCategories([challengeCategory, learningCategory])
    }
    
    // MARK: - Challenge Notifications
    
    func scheduleChallengeReminder(for challenge: LearnChallenge, context: NSManagedObjectContext) {
        guard let startDate = challenge.startDate,
              let endDate = challenge.endDate else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Challenge Reminder"
        content.body = "Don't forget to work on your '\(challenge.title ?? "")' challenge!"
        content.sound = .default
        content.categoryIdentifier = challengeCategory
        content.userInfo = ["challengeId": challenge.id?.uuidString ?? ""]
        
        // Schedule daily reminders for the duration of the challenge
        let calendar = Calendar.current
        var currentDate = startDate
        
        while currentDate <= endDate {
            if let components = calendar.dateComponents([.hour, .minute], from: Date()).date {
                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: calendar.dateComponents([.hour, .minute], from: components),
                    repeats: false
                )
                
                let request = UNNotificationRequest(
                    identifier: "challenge_\(challenge.id?.uuidString ?? "")_\(currentDate.timeIntervalSince1970)",
                    content: content,
                    trigger: trigger
                )
                
                notificationCenter.add(request)
            }
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endDate
        }
    }
    
    func scheduleCompletionReminder(for challenge: LearnChallenge) {
        guard let endDate = challenge.endDate else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Challenge Ending Soon"
        content.body = "Your '\(challenge.title ?? "")' challenge ends tomorrow. Make sure to complete all requirements!"
        content.sound = .default
        content.categoryIdentifier = challengeCategory
        
        let dateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: endDate.addingTimeInterval(-24 * 60 * 60)
        )
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(
            identifier: "challenge_completion_\(challenge.id?.uuidString ?? "")",
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request)
    }
    
    // MARK: - Learning Reminders
    
    func scheduleLearningReminder(at date: Date, category: LearnCategory) {
        let content = UNMutableNotificationContent()
        content.title = "Time to Learn"
        content.body = "Take a few minutes to learn about \(category.rawValue.lowercased())"
        content.sound = .default
        content.categoryIdentifier = learningCategory
        
        let dateComponents = Calendar.current.dateComponents(
            [.hour, .minute],
            from: date
        )
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "learning_\(category.rawValue)_\(date.timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request)
    }
    
    func scheduleStreakReminder(currentStreak: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Keep Your Learning Streak!"
        content.body = "You're on a \(currentStreak)-day streak. Don't break it!"
        content.sound = .default
        content.categoryIdentifier = learningCategory
        
        // Schedule for 8 PM if they haven't completed anything today
        var dateComponents = Calendar.current.dateComponents([.hour, .minute], from: Date())
        dateComponents.hour = 20
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(
            identifier: "streak_reminder_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request)
    }
    
    // MARK: - Notification Management
    
    func removeAllPendingNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
    }
    
    func removeChallengeNotifications(for challenge: LearnChallenge) {
        guard let challengeId = challenge.id?.uuidString else { return }
        
        notificationCenter.getPendingNotificationRequests { requests in
            let challengeNotifications = requests.filter { request in
                request.identifier.contains(challengeId)
            }
            
            self.notificationCenter.removePendingNotificationRequests(
                withIdentifiers: challengeNotifications.map { $0.identifier }
            )
        }
    }
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Error requesting notification authorization: \(error)")
            }
            completion(granted)
        }
    }
}

// MARK: - Notification Response Handling

extension LearnNotificationManager {
    func handleNotificationResponse(_ response: UNNotificationResponse, context: NSManagedObjectContext) {
        let userInfo = response.notification.request.content.userInfo
        
        switch response.actionIdentifier {
        case "MARK_COMPLETE":
            if let challengeIdString = userInfo["challengeId"] as? String,
               let challengeId = UUID(uuidString: challengeIdString) {
                markChallengeComplete(challengeId: challengeId, context: context)
            }
            
        case "SNOOZE":
            if let challengeIdString = userInfo["challengeId"] as? String {
                snoozeNotification(challengeId: challengeIdString)
            }
            
        case "VIEW":
            // Handle view action in the app's navigation
            break
            
        default:
            break
        }
    }
    
    private func markChallengeComplete(challengeId: UUID, context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<LearnChallenge> = LearnChallenge.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", challengeId as CVarArg)
        
        context.perform {
            do {
                if let challenge = try context.fetch(fetchRequest).first {
                    LearnProgressManager.shared.updateChallengeProgress(challenge, progress: 1.0, context: context)
                }
            } catch {
                print("Error marking challenge complete: \(error)")
            }
        }
    }
    
    private func snoozeNotification(challengeId: String) {
        // Schedule a reminder for 1 hour later
        let content = UNMutableNotificationContent()
        content.title = "Reminder"
        content.body = "Don't forget about your challenge!"
        content.sound = .default
        content.categoryIdentifier = challengeCategory
        content.userInfo = ["challengeId": challengeId]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60 * 60, repeats: false)
        let request = UNNotificationRequest(
            identifier: "snoozed_\(challengeId)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request)
    }
}