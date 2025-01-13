import SwiftUI
import CoreData
import HealthKit

/// Main settings interface for the Zeez sleep tracking app
/// Provides user configuration options for sleep goals, notifications,
/// HealthKit integration, and alarm preferences
struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [],
        animation: .default
    ) private var preferences: FetchedResults<UserPreferences>
    
    @State private var showingHealthKitAlert = false
    @State private var healthKitError: Error?
    
    private var userPreferences: UserPreferences {
        if let existing = preferences.first {
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
            notificationSection
            healthKitSection
            alarmSection
        }
        .navigationTitle("Settings")
        .alert("HealthKit Error", isPresented: $showingHealthKitAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            if let error = healthKitError {
                Text(error.localizedDescription)
            }
        }
    }
    
    private var sleepGoalSection: some View {
        Section("Sleep Goal") {
            Toggle("Enable Sleep Goal", isOn: binding(\.sleepGoalEnabled))
            
            if userPreferences.sleepGoalEnabled {
                DatePicker("Target Bedtime",
                          selection: Binding(
                              get: { self.userPreferences.targetBedtime ?? Date() },
                              set: { self.userPreferences.targetBedtime = $0 }
                          ),
                          displayedComponents: .hourAndMinute)

                DatePicker("Target Wake Time",
                          selection: Binding(
                              get: { self.userPreferences.targetWakeTime ?? Date() },
                              set: { self.userPreferences.targetWakeTime = $0 }
                          ),
                          displayedComponents: .hourAndMinute)
            }
        }
    }

    private var notificationSection: some View {
        Section("Notifications") {
            Toggle("Enable Notifications",
                   isOn: binding(\.notificationsEnabled))
        }
    }
    
    private var healthKitSection: some View {
        Section("Health Integration") {
            Toggle("Sync with Health App",
                   isOn: binding(\.healthKitSyncEnabled))
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
        }
    }
    
    /// Creates a binding for UserPreferences properties
    private func binding<T>(_ keyPath: ReferenceWritableKeyPath<UserPreferences, T>) -> Binding<T> {
        Binding(
            get: { userPreferences[keyPath: keyPath] },
            set: { newValue in
                viewContext.perform {
                    userPreferences[keyPath: keyPath] = newValue
                    userPreferences.modifiedAt = Date()
                    try? viewContext.save()
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
                    try? viewContext.save()
                }
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SettingsView()
                .environment(\.managedObjectContext,
                            PersistenceController.preview.container.viewContext)
        }
    }
}
