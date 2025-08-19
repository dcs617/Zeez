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
    
    @State private var showingHealthKitAlert = false
    @State private var healthKitError: Error?
    
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
            alarmSection
            
            #if DEBUG
            debugSection
            #endif
        }
        .navigationTitle("Settings")
        .alert("HealthKit Error", isPresented: $showingHealthKitAlert) {
            Button("OK", role: .cancel) {}
                .accessibilityLabel("OK")
                .accessibilityHint("Dismiss HealthKit error message")
        } message: {
            if let error = healthKitError {
                Text(error.localizedDescription)
            }
        }
    }
    
    private var sleepGoalSection: some View {
        Section("Sleep Goal") {
            Toggle("Enable Sleep Goal", isOn: binding(\.sleepGoalEnabled))
                .accessibilityLabel("Enable sleep goal tracking")
                .accessibilityHint("When enabled, set target bedtime and wake time for sleep recommendations")
                .accessibilityIdentifier("sleepGoalToggle")
            
            if userPreferences.sleepGoalEnabled {
                DatePicker("Target Bedtime",
                          selection: Binding(
                              get: { self.userPreferences.targetBedtime ?? Date() },
                              set: { self.userPreferences.targetBedtime = $0 }
                          ),
                          displayedComponents: .hourAndMinute)
                    .accessibilityLabel("Target bedtime")
                    .accessibilityHint("Set your preferred time to go to sleep")
                    .accessibilityIdentifier("targetBedtimePicker")

                DatePicker("Target Wake Time",
                          selection: Binding(
                              get: { self.userPreferences.targetWakeTime ?? Date() },
                              set: { self.userPreferences.targetWakeTime = $0 }
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
            .accessibilityHint("Manage your personalized sleep analysis settings and view your sleep patterns")
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
            Toggle("Sync with Health App",
                   isOn: binding(\.healthKitSyncEnabled))
                .accessibilityLabel("Sync with Health app")
                .accessibilityHint("Share sleep data with Apple Health for comprehensive health tracking")
                .accessibilityIdentifier("healthKitSyncToggle")
            .onChange(of: userPreferences.healthKitSyncEnabled) { oldValue, newValue in
                if newValue {
                    requestHealthKitPermissions()
                }
            }
        }
    }
    
    private var alarmSection: some View {
        Section("Alarm Settings") {
            NavigationLink("Configure Alarms") {
                AlarmSettingsView()
            }
            .accessibilityLabel("Configure alarms")
            .accessibilityHint("Set up and manage your smart wake-up alarms")
            .accessibilityIdentifier("configureAlarmsLink")
        }
    }
    
    #if DEBUG
    private var debugSection: some View {
        Section("🐛 Debug Tools") {
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
            
            Button("Debug Scheduled Alarms") {
                debugScheduledAlarms()
            }
            .accessibilityLabel("Debug scheduled alarms")
            .accessibilityHint("Shows all currently scheduled alarm notifications in console")
            
            Button("Test Full-Screen Alarm") {
                testFullScreenAlarm()
            }
            .accessibilityLabel("Test full-screen alarm interface")
            .accessibilityHint("Shows the full-screen alarm experience")
            
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
    
    /// Requests HealthKit permissions when sync is enabled
    private func requestHealthKitPermissions() {
        SleepSessionManager.shared.requestHealthKitAuthorization { success, error in
            if !success {
                healthKitError = error
                showingHealthKitAlert = true
                
                // Revert toggle if permission denied
                viewContext.perform {
                    userPreferences.healthKitSyncEnabled = false
                    do {
                        try viewContext.save()
                    } catch {
                        ZeezLogger.error(ZeezLogger.ui, "Failed to revert HealthKit setting", error: error)
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        SettingsView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
