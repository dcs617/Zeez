import SwiftUI
import CoreData
import UserNotifications
import os.log

struct LearnSettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("learnNotificationsEnabled") private var notificationsEnabled = false
    @AppStorage("learnReminderTime") private var reminderTime = Calendar.current.date(from: DateComponents(hour: 20, minute: 0)) ?? Date()
    @AppStorage("learnStreakEnabled") private var streakEnabled = true
    @AppStorage("showCompletedChallenges") private var showCompletedChallenges = true
    @AppStorage("autoPlayVideos") private var autoPlayVideos = true
    @AppStorage("useDataSaver") private var useDataSaver = false
    @AppStorage("autoDownloadContent") private var autoDownloadContent = false
    
    @State private var showingNotificationsDenied = false
    @State private var showingResetConfirmation = false
    @State private var showingDataClearedAlert = false
    @State private var showingCacheClearedAlert = false
    
    @StateObject private var offlineManager = LearnOfflineManager.shared
    
    var body: some View {
        Form {
            notificationSection
            trackingSection
            contentSection
            offlineSection
            dataSection
        }
        .navigationTitle("Learn Settings")
        .alert("Notifications Denied", isPresented: $showingNotificationsDenied) {
            Button("Open Settings", action: openSettings)
            .accessibilityLabel("Open device settings")
            .accessibilityHint("Open Settings app to enable notifications")
            Button("Cancel", role: .cancel) { }
            .accessibilityLabel("Cancel")
            .accessibilityHint("Close alert without opening settings")
        } message: {
            Text("Enable notifications in Settings to receive learning reminders.")
        }
        .alert("Reset Progress?", isPresented: $showingResetConfirmation) {
            Button("Reset", role: .destructive, action: resetProgress)
            .accessibilityLabel("Reset progress")
            .accessibilityHint("Permanently reset all learning progress")
            Button("Cancel", role: .cancel) { }
            .accessibilityLabel("Cancel")
            .accessibilityHint("Keep current progress and close alert")
        } message: {
            Text("This will reset all your learning progress, including completed articles, challenges, and achievements. This action cannot be undone.")
        }
        .alert("Cache Cleared", isPresented: $showingCacheClearedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("All offline content has been cleared.")
        }
    }
    
    private var notificationSection: some View {
        Section {
            Toggle(isOn: $notificationsEnabled) {
                Label {
                    Text("Learning Reminders")
                } icon: {
                    Image(systemName: "bell")
                }
            }
            .onChange(of: notificationsEnabled) { _, isEnabled in
                handleNotificationToggle(isEnabled)
            }
            .accessibilityLabel("Learning reminders")
            .accessibilityHint(notificationsEnabled ? "Disable daily learning reminders" : "Enable daily learning reminders")
            .accessibilityIdentifier("learningRemindersToggle")
            
            if notificationsEnabled {
                DatePicker("Reminder Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    .onChange(of: reminderTime) { _, _ in
                        updateNotificationSchedule()
                    }
                    .accessibilityLabel("Reminder time")
                    .accessibilityHint("Set the time for daily learning reminders")
                    .accessibilityIdentifier("reminderTimePicker")
                
                Toggle(isOn: $streakEnabled) {
                    Label {
                        Text("Streak Reminders")
                    } icon: {
                        Image(systemName: "flame")
                    }
                }
                .accessibilityLabel("Streak reminders")
                .accessibilityHint(streakEnabled ? "Disable streak reminder notifications" : "Enable streak reminder notifications")
                .accessibilityIdentifier("streakRemindersToggle")
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text("Daily reminders to help you maintain your learning habit")
        }
    }
    
    private var trackingSection: some View {
        Section {
            Toggle(isOn: $showCompletedChallenges) {
                Label {
                    Text("Show Completed")
                } icon: {
                    Image(systemName: "checkmark.circle")
                }
            }
            .accessibilityLabel("Show completed challenges")
            .accessibilityHint(showCompletedChallenges ? "Hide completed challenges from view" : "Show completed challenges in lists")
            .accessibilityIdentifier("showCompletedChallengesToggle")
            
            NavigationLink {
                LearnAchievementView()
            } label: {
                Label {
                    Text("Achievements")
                } icon: {
                    Image(systemName: "trophy")
                }
            }
            .accessibilityLabel("View achievements")
            .accessibilityHint("Navigate to your learning achievements")
            .accessibilityIdentifier("achievementsNavigationLink")
            
            NavigationLink {
                LearnStatisticsView()
            } label: {
                Label {
                    Text("Statistics")
                } icon: {
                    Image(systemName: "chart.bar")
                }
            }
            .accessibilityLabel("View statistics")
            .accessibilityHint("Navigate to your learning statistics")
            .accessibilityIdentifier("statisticsNavigationLink")
        } header: {
            Text("Progress Tracking")
        }
    }
    
    private var contentSection: some View {
        Section {
            Toggle(isOn: $autoPlayVideos) {
                Label {
                    Text("Auto-play Videos")
                } icon: {
                    Image(systemName: "play.circle")
                }
            }
            .accessibilityLabel("Auto-play videos")
            .accessibilityHint(autoPlayVideos ? "Disable automatic video playback" : "Enable automatic video playback")
            .accessibilityIdentifier("autoPlayVideosToggle")
            
            Toggle(isOn: $useDataSaver) {
                Label {
                    Text("Data Saver")
                } icon: {
                    Image(systemName: "speedometer")
                }
            }
            .accessibilityLabel("Data saver mode")
            .accessibilityHint(useDataSaver ? "Disable data saver to load full quality content" : "Enable data saver to reduce data usage")
            .accessibilityIdentifier("dataSaverToggle")
        } header: {
            Text("Content")
        } footer: {
            Text("Data saver mode will load lower quality images and disable auto-play")
        }
    }
    
    private var offlineSection: some View {
        Section {
            Toggle(isOn: $autoDownloadContent) {
                Label {
                    Text("Auto Download")
                } icon: {
                    Image(systemName: "arrow.down.circle")
                }
            }
            .accessibilityLabel("Auto download content")
            .accessibilityHint(autoDownloadContent ? "Disable automatic content downloads" : "Enable automatic content downloads on WiFi")
            .accessibilityIdentifier("autoDownloadToggle")
            
            if !offlineManager.offlineArticles.isEmpty {
                Button(role: .destructive) {
                    clearOfflineContent()
                } label: {
                    Label {
                        Text("Clear Offline Content")
                    } icon: {
                        Image(systemName: "trash")
                    }
                }
                .accessibilityLabel("Clear offline content")
                .accessibilityHint("Remove all downloaded content from device")
                .accessibilityIdentifier("clearOfflineContentButton")
            }
        } header: {
            Text("Offline Access")
        } footer: {
            Text("Auto download will save articles for offline reading when on WiFi")
        }
    }
    
    private var dataSection: some View {
        Section {
            Button(role: .destructive) {
                showingResetConfirmation = true
            } label: {
                Label {
                    Text("Reset Progress")
                } icon: {
                    Image(systemName: "arrow.counterclockwise")
                }
            }
            .accessibilityLabel("Reset progress")
            .accessibilityHint("Reset all learning progress data")
            .accessibilityIdentifier("resetProgressButton")
        } header: {
            Text("Data")
        } footer: {
            Text("Resetting progress will remove all completion data but keep your bookmarks")
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleNotificationToggle(_ isEnabled: Bool) {
        if isEnabled {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
                DispatchQueue.main.async {
                    if granted {
                        self.notificationsEnabled = true
                        self.updateNotificationSchedule()
                    } else {
                        self.notificationsEnabled = false
                        self.showingNotificationsDenied = true
                    }
                }
            }
        } else {
            LearnNotificationManager.shared.removeAllPendingNotifications()
        }
    }
    
    private func updateNotificationSchedule() {
        guard notificationsEnabled else { return }
        
        // Schedule learning reminders
        LearnNotificationManager.shared.scheduleLearningReminder(at: reminderTime, category: .basics)
        
        // Schedule streak reminders if enabled
        if streakEnabled {
            // Get current streak from CoreData and schedule reminder
            let fetchRequest: NSFetchRequest<UserArticleProgress> = UserArticleProgress.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "lastReadDate > %@",
                Calendar.current.date(byAdding: .day, value: -7, to: Date())! as NSDate)
            
            do {
                let progress = try viewContext.fetch(fetchRequest)
                let uniqueDays = Set(progress.compactMap { $0.lastReadDate }).count
                if uniqueDays > 0 {
                    LearnNotificationManager.shared.scheduleStreakReminder(currentStreak: uniqueDays)
                }
            } catch {
                ZeezLogger.error(ZeezLogger.learning, "Error fetching streak data", error: error)
            }
        }
    }
    
    private func resetProgress() {
        viewContext.perform {
            // Reset article progress
            let articleRequest: NSFetchRequest<UserArticleProgress> = UserArticleProgress.fetchRequest()
            if let progress = try? viewContext.fetch(articleRequest) {
                for item in progress {
                    item.isCompleted = false
                    item.lastReadDate = nil
                }
            }
            
            // Reset challenge progress
            let challengeRequest: NSFetchRequest<ChallengeBadge> = ChallengeBadge.fetchRequest()
            if let badges = try? viewContext.fetch(challengeRequest) {
                for badge in badges {
                    badge.isCompleted = false
                    badge.progress = 0
                    badge.earnedDate = nil
                }
            }
            
            do {
                try viewContext.save()
                showingDataClearedAlert = true
            } catch {
                ZeezLogger.error(ZeezLogger.learning, "Error resetting progress", error: error)
            }
        }
    }
    
    private func clearOfflineContent() {
        // Get all offline articles and remove them
        let fetchRequest: NSFetchRequest<LearnArticle> = LearnArticle.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "objectID IN %@", offlineManager.offlineArticles)
        
        if let articles = try? viewContext.fetch(fetchRequest) {
            articles.forEach { article in
                offlineManager.removeFromOffline(article: article)
            }
        }
        
        showingCacheClearedAlert = true
    }
    
    private func openSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

#Preview {
    NavigationView {
        LearnSettingsView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
