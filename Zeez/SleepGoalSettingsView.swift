import SwiftUI
import CoreData

/// View for configuring sleep goals, schedules, and preferences
struct SleepGoalSettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @FetchRequest<UserPreferences>(
        sortDescriptors: [],
        animation: .default
    ) private var preferences

    // Local state for editing
    @State private var sleepGoalEnabled: Bool
    @State private var targetBedtime: Date
    @State private var targetWakeTime: Date
    @State private var selectedDays: Set<Int>
    @State private var showingRecommendations = false
    
    // Initialize from current preferences or defaults
    init() {
        let currentPreferences = PersistenceController.shared.container.viewContext
            .fetchUserPreferences()
        
        _sleepGoalEnabled = State(initialValue: currentPreferences?.sleepGoalEnabled ?? false)
        _targetBedtime = State(initialValue: currentPreferences?.targetBedtime ?? Date())
        _targetWakeTime = State(initialValue: currentPreferences?.targetWakeTime ?? Date())
        _selectedDays = State(initialValue: Set(0..<7))
    }
    
    var body: some View {
        NavigationView {
            Form {
                sleepGoalSection
                scheduleSection
                recommendationsSection
                calculatedMetricsSection
            }
            .navigationTitle("Sleep Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { savePreferences() }
                }
            }
        }
    }
    
    private var sleepGoalSection: some View {
        Section {
            Toggle("Enable Sleep Goal", isOn: $sleepGoalEnabled)
            
            if sleepGoalEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recommended Sleep")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("7-9 hours for adults")
                        .font(.caption)
                }
                
                DatePicker("Target Bedtime",
                          selection: $targetBedtime,
                          displayedComponents: .hourAndMinute)
                
                DatePicker("Target Wake Time",
                          selection: $targetWakeTime,
                          displayedComponents: .hourAndMinute)
            }
        } footer: {
            if sleepGoalEnabled {
                Text("Your target sleep duration: \(formattedSleepDuration)")
                    .font(.caption)
            }
        }
    }
    
    private var scheduleSection: some View {
        Section {
            ForEach(Calendar.current.weekdaySymbols.indices, id: \.self) { index in
                Toggle(Calendar.current.weekdaySymbols[index],
                       isOn: Binding(
                        get: { selectedDays.contains(index) },
                        set: { isSelected in
                            if isSelected {
                                selectedDays.insert(index)
                            } else {
                                selectedDays.remove(index)
                            }
                        }
                       ))
            }
        } header: {
            Text("Schedule")
        } footer: {
            Text("Your sleep goal will be active on selected days")
        }
    }
    
    private var recommendationsSection: some View {
        Section {
            Button(action: { showingRecommendations = true }) {
                HStack {
                    Image(systemName: "lightbulb")
                        .foregroundColor(.yellow)
                    Text("Get Personalized Recommendations")
                }
            }
        } footer: {
            Text("Based on your age, activity level, and sleep history")
        }
    }
    
    private var calculatedMetricsSection: some View {
        Section("Calculated Metrics") {
            HStack {
                Text("Weekly Sleep Debt")
                Spacer()
                Text(calculateWeeklySleepDebt())
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Monthly Average")
                Spacer()
                Text(calculateMonthlyAverage())
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var formattedSleepDuration: String {
        let duration = targetWakeTime.timeIntervalSince(targetBedtime)
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        return String(format: "%dh %02dm", hours, minutes)
    }
    
    private func savePreferences() {
        let context = viewContext
        let prefs = preferences.first ?? UserPreferences(context: context)
        
        prefs.id = prefs.id ?? UUID()
        prefs.sleepGoalEnabled = sleepGoalEnabled
        prefs.targetBedtime = targetBedtime
        prefs.targetWakeTime = targetWakeTime
        prefs.targetSleepDuration = targetWakeTime.timeIntervalSince(targetBedtime)
        prefs.modifiedAt = Date()
        
        if prefs.createdAt == nil {
            prefs.createdAt = Date()
        }
        
        do {
            try context.save()
            ErrorManager.shared.showStatus("Sleep goals updated")
            dismiss()
        } catch {
            ErrorManager.shared.reportError(error)
        }
    }
    
    private func calculateWeeklySleepDebt() -> String {
        // To be implemented with actual sleep data
        return "2h 30m"
    }
    
    private func calculateMonthlyAverage() -> String {
        // To be implemented with actual sleep data
        return "7h 15m"
    }
}

// Helper extension to fetch UserPreferences
extension NSManagedObjectContext {
    func fetchUserPreferences() -> UserPreferences? {
        let request: NSFetchRequest<UserPreferences> = UserPreferences.fetchRequest()
        request.fetchLimit = 1
        return try? fetch(request).first
    }
}

struct SleepGoalSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SleepGoalSettingsView()
            .environment(\.managedObjectContext,
                        PersistenceController.preview.container.viewContext)
    }
}
