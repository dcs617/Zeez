import UserNotifications
import CoreData
import os.log

class LearnNotificationManager {
    static let shared = LearnNotificationManager()

    private let notificationCenter = UNUserNotificationCenter.current()
    /// Every Learn-owned request identifier starts with this prefix so bulk
    /// removal can target Learn notifications without touching alarms.
    private static let identifierPrefix = "learn-"
    
    /// Learn registers no notification categories: `setNotificationCategories` replaces the
    /// whole set, so only `AlarmNotificationRegistrar` calls it, and the alarm keeps Snooze,
    /// Continue and Stop. Learn notifications carry no actions; a tap only opens the app.
    private init() {}
    
    // MARK: - Challenge Notifications
    
    func scheduleChallengeReminder(for challenge: LearnChallenge, context: NSManagedObjectContext) {
        guard let startDate = challenge.startDate,
              let endDate = challenge.endDate else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Challenge Reminder"
        content.body = "Don't forget to work on your '\(challenge.title ?? "")' challenge!"
        content.sound = .default
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
                    identifier: "\(Self.identifierPrefix)challenge_\(challenge.id?.uuidString ?? "")_\(currentDate.timeIntervalSince1970)",
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
        
        let dateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: endDate.addingTimeInterval(-AppConstants.Learning.dailyFactInterval)
        )
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(Self.identifierPrefix)challenge_completion_\(challenge.id?.uuidString ?? "")",
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
        
        let dateComponents = Calendar.current.dateComponents(
            [.hour, .minute],
            from: date
        )
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "\(Self.identifierPrefix)learning_\(category.rawValue)_\(date.timeIntervalSince1970)",
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
        
        // Schedule for 8 PM if they haven't completed anything today
        var dateComponents = Calendar.current.dateComponents([.hour, .minute], from: Date())
        dateComponents.hour = 20
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(Self.identifierPrefix)streak_reminder_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request)
    }
    
    // MARK: - Notification Management
    
    /// Remove all Learn-owned pending notifications. Filters on the "learn-"
    /// identifier prefix — a global removeAllPendingNotificationRequests()
    /// here would cancel every scheduled alarm (toggling Learn notifications
    /// off in settings used to do exactly that).
    func removeAllPendingNotifications() {
        notificationCenter.getPendingNotificationRequests { [notificationCenter] requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(Self.identifierPrefix) }
            if !ids.isEmpty {
                notificationCenter.removePendingNotificationRequests(withIdentifiers: ids)
            }
        }
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
                ZeezLogger.error(ZeezLogger.learning, "Error requesting notification authorization", error: error)
            }
            completion(granted)
        }
    }
}
