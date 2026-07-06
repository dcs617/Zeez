import SwiftUI
import CoreData
import HealthKit
import os.log

/// Main settings interface for the Zeez sleep tracking app
/// Provides user configuration options for sleep goals, notifications,
/// HealthKit integration, and alarm preferences
struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest<UserPreferences>(
        sortDescriptors: [],
        animation: .default
    ) private var preferences
    
    @State private var healthKitError: Error?
    @State private var importStatus: String = ""
    @State private var isImporting = false
    @State private var hasRealDataCached: Bool = false
    @State private var showingDeleteAllConfirmation = false
    
    @StateObject private var modalCoordinator = ModalCoordinator.shared
    
    private var preferencesArray: [UserPreferences] {
        Array(preferences)
    }
    
    private var userPreferences: UserPreferences {
        if let existing = preferencesArray.first {
            return existing
        }
        let new = UserPreferences(context: viewContext)
        new.id = UUID()
        new.createdAt = Date()
        new.modifiedAt = Date()
        return new
    }
    
    var body: some View {
        Form {
            sleepGoalSection
            personalizationSection
            notificationSection
            healthKitSection
            dataImportSection
            alarmSection
            privacySection

            #if DEBUG
            debugSection
            #endif
        }
        .navigationTitle("Settings")
        .confirmationDialog(
            "Delete All My Data?",
            isPresented: $showingDeleteAllConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Everything", role: .destructive) {
                deleteAllUserData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes all sleep sessions, alarms, and settings from this device. Data in Apple Health is not affected. This cannot be undone.")
        }
    }

    private var privacySection: some View {
        Section("Privacy & Data") {
            Link("Privacy Policy", destination: AppConstants.Legal.privacyPolicyURL)
                .accessibilityLabel("Privacy Policy")
                .accessibilityHint("Opens the Zeez privacy policy in your browser")
                .accessibilityIdentifier("privacyPolicyLink")

            Button(role: .destructive) {
                showingDeleteAllConfirmation = true
            } label: {
                Text("Delete All My Data")
            }
            .accessibilityLabel("Delete All My Data")
            .accessibilityHint("Permanently deletes all sleep data, alarms, and settings from this device")
            .accessibilityIdentifier("deleteAllDataButton")

            HStack {
                Text("Version")
                Spacer()
                Text(appVersionString)
                    .foregroundColor(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("App version \(appVersionString)")
            .accessibilityIdentifier("appVersionRow")
        }
    }

    private var appVersionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(version) (\(build))"
    }

    private func deleteAllUserData() {
        // Wipe the Core Data store (recreated empty in place).
        PersistenceController.shared.clearAllData()

        // Reset preferences to first-run state. The StoreKit-backed subscription
        // cache survives: entitlements belong to the Apple Account, not app data.
        let defaults = UserDefaults.standard
        let subscriptionTier = defaults.string(forKey: "subscription_tier")
        if let bundleID = Bundle.main.bundleIdentifier {
            defaults.removePersistentDomain(forName: bundleID)
        }
        if let subscriptionTier {
            defaults.set(subscriptionTier, forKey: "subscription_tier")
        }

        // Every alarm and reminder references data that no longer exists, so a
        // global wipe is correct here — unlike routine rescheduling (see the
        // prefix-filtered removals in AlarmScheduler/LearnNotificationManager).
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()

        ZeezLogger.info(ZeezLogger.app, "All user data deleted at user request")

        // Return to onboarding immediately (RootView observes this) and close
        // the settings modal.
        OnboardingManager.shared.reset()
        modalCoordinator.dismiss()
    }
    
    private var sleepGoalSection: some View {
        Section("Sleep Goal") {
            Toggle("Enable Sleep Goal", isOn: binding(\.sleepGoalEnabled))
                .accessibilityLabel("Enable sleep goal tracking")
                .accessibilityHint("When enabled, compare recorded sleep duration with your selected goal")
                .accessibilityIdentifier("sleepGoalToggle")
            
            if userPreferences.sleepGoalEnabled {
                DatePicker("Target Bedtime",
                          selection: Binding(
                              get: { self.userPreferences.targetBedtime ?? Date() },
                              set: {
                                  self.userPreferences.targetBedtime = $0
                                  updateTargetSleepDuration()
                              }
                          ),
                          displayedComponents: .hourAndMinute)
                    .accessibilityLabel("Target bedtime")
                    .accessibilityHint("Set your preferred time to go to sleep")
                    .accessibilityIdentifier("targetBedtimePicker")

                DatePicker("Target Wake Time",
                          selection: Binding(
                              get: { self.userPreferences.targetWakeTime ?? Date() },
                              set: {
                                  self.userPreferences.targetWakeTime = $0
                                  updateTargetSleepDuration()
                              }
                          ),
                          displayedComponents: .hourAndMinute)
                    .accessibilityLabel("Target wake time")
                    .accessibilityHint("Set your preferred time to wake up")
                    .accessibilityIdentifier("targetWakeTimePicker")
            }
        }
    }
    
    private var personalizationSection: some View {
        Section("Sleep Analysis") {
            NavigationLink("Personalization") {
                PersonalizationSettingsView()
            }
            .accessibilityLabel("Sleep analysis personalization")
            .accessibilityHint("View the current availability of personalization features")
            .accessibilityIdentifier("personalizationSettingsLink")
        }
    }

    private var notificationSection: some View {
        Section("Notifications") {
            Toggle("Enable Notifications",
                   isOn: binding(\.notificationsEnabled))
                .accessibilityLabel("Enable notifications")
                .accessibilityHint("Allow the app to send sleep reminders and wake-up notifications")
                .accessibilityIdentifier("notificationsToggle")
        }
    }
    
    private var healthKitSection: some View {
        Section("Health Integration") {
            Toggle("Import from Apple Health",
                   isOn: binding(\.healthKitSyncEnabled))
                .accessibilityLabel("Import from Apple Health")
                .accessibilityHint("Enable importing sleep and health data from Apple Health")
                .accessibilityIdentifier("healthKitSyncToggle")
            .onChange(of: userPreferences.healthKitSyncEnabled) { oldValue, newValue in
                if newValue, !modalCoordinator.isPresenting(.dataImport) {
                    requestHealthKitPermissions()
                }
            }
        }
    }
    
    private var dataImportSection: some View {
        Section("Sleep Data") {
            let dataManager = RealDataManager.shared
            let dataSources = dataManager.getDataSources()
            
            VStack(alignment: .leading, spacing: 8) {
                if hasRealDataCached {
                    Label("Using your real sleep data", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Label("Using simulated data", systemImage: "waveform.path")
                        .foregroundColor(.orange)
                }
                
                // Data source summary
                if let healthKitCount = dataSources[.healthKit]?.count, healthKitCount > 0 {
                    Text("HealthKit: \(healthKitCount) sessions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let pillowCount = dataSources[.pillow]?.count, pillowCount > 0 {
                    Text("Pillow: \(pillowCount) sessions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let mockCount = dataSources[.mock]?.count, mockCount > 0 {
                    Text("Mock: \(mockCount) sessions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Data source information")
            
            Button("Import Sleep Data") {
                // Prevent rapid taps and ensure no other modal is active
                guard modalCoordinator.canPresent() && !isImporting else { 
                    ZeezLogger.debug(ZeezLogger.coreData, "Import button tap blocked - canPresent: \(modalCoordinator.canPresent()), isImporting: \(isImporting)")
                    return 
                }
                ZeezLogger.info(ZeezLogger.coreData, "📱 User tapped Import Sleep Data in Settings")
                modalCoordinator.present(.dataImport)
            }
            .disabled(isImporting || !modalCoordinator.canPresent())
            .accessibilityLabel("Import sleep data")
            .accessibilityHint("Import sleep data from Apple Health")
            
            if !importStatus.isEmpty {
                Text(importStatus)
                    .font(.caption)
                    .foregroundColor(importStatus.contains("Error") ? .red : .green)
                    .accessibilityLabel("Import status: \(importStatus)")
            }
            
            // Show Clear Mock Data button when mock data exists
            let mockCount = dataSources[.mock]?.count ?? 0
            if mockCount > 0 {
                Button("Clear Mock Data (\(mockCount) sessions)") {
                    clearMockData()
                }
                .foregroundColor(.red)
                .accessibilityLabel("Clear simulated data")
                .accessibilityHint("Remove all \(mockCount) generated test sessions")
            }
            
        }
        .onAppear {
            updateRealDataStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ModalDismissed"))) { _ in
            // Refresh data status when modal is dismissed
            updateRealDataStatus()
        }
    }
    
    private var alarmSection: some View {
        Section("Alarm Settings") {
            NavigationLink("Configure Alarms") {
                AlarmSettingsView()
            }
            .accessibilityLabel("Configure alarms")
            .accessibilityHint("Set up and manage your wake-up alarms")
            .accessibilityIdentifier("configureAlarmsLink")
        }
    }
    
    #if DEBUG
    private var debugSection: some View {
        Section("🐛 Debug Tools") {
            // New alarm system testing
            Button("🔔 Test New Alarm System (10s)") {
                AlarmScheduler.shared.scheduleTestNotification()
            }
            .accessibilityLabel("Test new alarm system")
            .accessibilityHint("Sends a test notification using the new alarm system in 10 seconds")
            
            Button("🔄 Test Follow-Up Notifications") {
                testFollowUpNotifications()
            }
            .accessibilityLabel("Test follow-up notifications")
            .accessibilityHint("Tests the continuous ringing simulation with follow-ups")
            
            Button("😴 Test Heavy Sleeper Mode") {
                testHeavySleeperMode()
            }
            .accessibilityLabel("Test heavy sleeper mode")
            .accessibilityHint("Tests faster follow-up notifications for heavy sleepers")
            
            Button("🔊 Test Audio Controller") {
                testAudioController()
            }
            .accessibilityLabel("Test audio controller")
            .accessibilityHint("Tests the continuous alarm audio playback")
            
            Divider()
            
            // Legacy testing
            Button("Test Notification (10s)") {
                testNotificationSystem()
            }
            .accessibilityLabel("Test notification system")
            .accessibilityHint("Sends a test notification in 10 seconds")
            
            Button("Check Alarm Permissions") {
                checkAlarmPermissions()
            }
            .accessibilityLabel("Check notification permissions")
            .accessibilityHint("Displays current notification authorization status")
            
            Button("Test Full-Screen Alarm") {
                testFullScreenAlarm()
            }
            .accessibilityLabel("Test full-screen alarm interface")
            .accessibilityHint("Shows the full-screen alarm experience")
            
            Divider()
            
            // Debug info
            Button("Debug Scheduled Alarms") {
                debugScheduledAlarms()
            }
            .accessibilityLabel("Debug scheduled alarms")
            .accessibilityHint("Shows all currently scheduled alarm notifications in console")
            
            Button("🔍 Validate Alarm Data") {
                validateAlarmData()
            }
            .accessibilityLabel("Validate alarm data")
            .accessibilityHint("Runs data validation and migration for alarm configurations")
            
            Button("Clear All Scheduled Alarms") {
                clearAllScheduledAlarms()
            }
            .accessibilityLabel("Clear all scheduled notifications")
            .accessibilityHint("Removes all scheduled alarm notifications")
        }
    }
    
    private func testNotificationSystem() {
        AlarmScheduler.shared.scheduleTestNotification()
        ZeezLogger.info(ZeezLogger.alarm, "🧪 Test notification scheduled - check your device in 10 seconds!")
    }
    
    private func checkAlarmPermissions() {
        AlarmScheduler.shared.checkNotificationPermissions { status in
            DispatchQueue.main.async {
                let statusString = switch status {
                case .notDetermined: "Not Determined"
                case .denied: "❌ DENIED"
                case .authorized: "✅ AUTHORIZED"
                case .provisional: "Provisional"
                case .ephemeral: "Ephemeral"
                @unknown default: "Unknown"
                }
                
                ZeezLogger.info(ZeezLogger.alarm, "🔐 Notification Permission Status: \(statusString)")
                
                if status == .denied {
                    ZeezLogger.error(ZeezLogger.alarm, "⚠️ Alarms will NOT work! Go to Settings > Notifications > Zeez to enable.")
                }
            }
        }
    }
    
    private func debugScheduledAlarms() {
        AlarmScheduler.shared.debugScheduledAlarms()
        ZeezLogger.info(ZeezLogger.alarm, "📊 Check console for scheduled alarm details")
    }
    
    private func testFullScreenAlarm() {
        // Create a test alarm
        let testAlarm = AlarmConfiguration(context: viewContext)
        testAlarm.id = UUID()
        testAlarm.name = "Test Alarm"
        testAlarm.alarmSound = "default"
        testAlarm.vibrationOnly = false
        
        // Show the full-screen alarm
        NotificationCenter.default.post(
            name: NSNotification.Name("ShowActiveAlarm"),
            object: testAlarm
        )
        
        ZeezLogger.info(ZeezLogger.alarm, "🧪 Full-screen alarm test triggered")
    }
    
    private func clearAllScheduledAlarms() {
        AlarmScheduler.shared.cancelAllAlarms()
        ZeezLogger.info(ZeezLogger.alarm, "🗑️ All scheduled alarms cleared")
        
        // Show updated debug info
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            AlarmScheduler.shared.debugScheduledAlarms()
        }
    }
    
    private func testFollowUpNotifications() {
        // Create a test notification that will trigger follow-ups
        let content = UNMutableNotificationContent()
        content.title = "Test Alarm Follow-Ups"
        content.body = "This will test the follow-up notification system"
        content.categoryIdentifier = AlarmNotificationRegistrar.categoryId
        content.interruptionLevel = .timeSensitive
        content.sound = .default
        content.userInfo = [
            "alarmID": "test-follow-up-\(UUID().uuidString)",
            "type": "main"  // This triggers follow-up logic
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
        let request = UNNotificationRequest(identifier: "test-follow-ups", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                ZeezLogger.error(ZeezLogger.alarm, "Failed to schedule follow-up test", error: error)
            } else {
                ZeezLogger.info(ZeezLogger.alarm, "🔄 Follow-up test scheduled! Expect follow-ups every 60s after main notification")
            }
        }
    }
    
    private func testHeavySleeperMode() {
        // Create a test notification simulating heavy sleeper mode
        let content = UNMutableNotificationContent()
        content.title = "Heavy Sleeper Test"
        content.body = "This will test faster follow-ups (31s intervals)"
        content.categoryIdentifier = AlarmNotificationRegistrar.categoryId
        content.interruptionLevel = .timeSensitive
        content.sound = .default
        content.userInfo = [
            "alarmID": "test-heavy-sleeper-\(UUID().uuidString)",
            "type": "main"
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: "test-heavy-sleeper", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                ZeezLogger.error(ZeezLogger.alarm, "Failed to schedule heavy sleeper test", error: error)
            } else {
                ZeezLogger.info(ZeezLogger.alarm, "😴 Heavy sleeper test scheduled! Expect follow-ups every 31s")
            }
        }
    }
    
    private func testAudioController() {
        if AlarmAudioController.shared.isPlaying {
            AlarmAudioController.shared.stop()
            ZeezLogger.info(ZeezLogger.alarm, "🔇 Stopped audio controller test")
        } else {
            if AlarmAudioController.shared.canPlay(bundledName: AlarmNotificationUtils.longInAppBundledName) {
                AlarmAudioController.shared.startLooping(bundledName: AlarmNotificationUtils.longInAppBundledName)
                ZeezLogger.info(ZeezLogger.alarm, "🔊 Started continuous audio test - tap again to stop")
            } else {
                // Test with a fallback
                AlarmAudioController.shared.startLooping(bundledName: "test_sound", fileExtension: "caf")
                ZeezLogger.info(ZeezLogger.alarm, "🔊 Started audio test with fallback - tap again to stop")
            }
        }
    }
    
    private func validateAlarmData() {
        AlarmDataMigrationHelper.performMigrationAndValidation(context: viewContext)
        ZeezLogger.info(ZeezLogger.alarm, "🔍 Alarm data validation completed - check console for details")
    }
    #endif
    
    /// Creates a binding for UserPreferences properties
    private func binding<T>(_ keyPath: ReferenceWritableKeyPath<UserPreferences, T>) -> Binding<T> {
        Binding(
            get: { userPreferences[keyPath: keyPath] },
            set: { newValue in
                viewContext.perform {
                    userPreferences[keyPath: keyPath] = newValue
                    userPreferences.modifiedAt = Date()
                    do {
                        try viewContext.save()
                    } catch {
                        ZeezLogger.error(ZeezLogger.ui, "Failed to save preference", error: error)
                        // Could revert the change and show error to user
                    }
                }
            }
        )
    }

    private func updateTargetSleepDuration() {
        guard let bedtime = userPreferences.targetBedtime,
              let wakeTime = userPreferences.targetWakeTime else { return }
        userPreferences.targetSleepDuration = SleepGoalPolicy.duration(from: bedtime, to: wakeTime)
        userPreferences.modifiedAt = Date()
        do {
            try viewContext.save()
        } catch {
            ZeezLogger.error(ZeezLogger.ui, "Failed to save sleep goal duration", error: error)
        }
    }
    
    /// Requests HealthKit permissions when sync is enabled (only when import modal isn't active)
    private func requestHealthKitPermissions() {
        SleepSessionManager.shared.requestHealthKitAuthorization { success, error in
            if !success {
                // Revert toggle if permission denied
                viewContext.perform {
                    userPreferences.healthKitSyncEnabled = false
                    do {
                        try viewContext.save()
                    } catch {
                        ZeezLogger.error(ZeezLogger.ui, "Failed to revert HealthKit setting", error: error)
                    }
                }
                
                // Log error instead of showing modal to avoid conflicts
                if let error = error {
                    ZeezLogger.error(ZeezLogger.error, "HealthKit permission denied: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func clearMockData() {
        RealDataManager.shared.clearMockData { result in
            switch result {
            case .success(let count):
                importStatus = "Cleared \(count) mock sessions"
            case .failure(let error):
                importStatus = "Error clearing data: \(error.localizedDescription)"
            }
        }
    }
    
    private func updateRealDataStatus() {
        hasRealDataCached = RealDataManager.shared.hasRealData()
    }
    
    #if DEBUG
    #endif
}

#Preview {
    NavigationView {
        SettingsView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
