import SwiftUI
import CoreData
import os.log

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
                    .accessibilityIdentifier("sleepGoalSection")
                scheduleSection
                    .accessibilityIdentifier("scheduleSection")
                recommendationsSection
                    .accessibilityIdentifier("recommendationsSection")
                calculatedMetricsSection
                    .accessibilityIdentifier("calculatedMetricsSection")
            }
            .navigationTitle("Sleep Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .accessibilityLabel("Cancel sleep goal settings")
                        .accessibilityHint("Discard changes and return to previous screen")
                        .accessibilityIdentifier("cancelButton")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { savePreferences() }
                        .accessibilityLabel("Save sleep goal settings")
                        .accessibilityHint("Save your sleep goal preferences and schedule")
                        .accessibilityIdentifier("saveButton")
                }
            }
        }
        .accessibilityIdentifier("sleepGoalSettingsView")
    }
    
    private var sleepGoalSection: some View {
        Section {
            Toggle("Enable Sleep Goal", isOn: $sleepGoalEnabled)
                .accessibilityLabel("Enable sleep goal tracking")
                .accessibilityHint(sleepGoalEnabled ? "Sleep goal is currently enabled" : "Sleep goal is currently disabled")
                .accessibilityIdentifier("sleepGoalToggle")
            
            if sleepGoalEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recommended Sleep")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("recommendedSleepHeader")
                    Text("7-9 hours for adults")
                        .font(.caption)
                        .accessibilityLabel("Recommended sleep duration is 7 to 9 hours for adults")
                        .accessibilityIdentifier("recommendedSleepText")
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("recommendedSleepInfo")
                
                DatePicker("Target Bedtime",
                          selection: $targetBedtime,
                          displayedComponents: .hourAndMinute)
                    .accessibilityLabel("Target bedtime")
                    .accessibilityHint("Set your preferred bedtime")
                    .accessibilityIdentifier("targetBedtimePicker")
                
                DatePicker("Target Wake Time",
                          selection: $targetWakeTime,
                          displayedComponents: .hourAndMinute)
                    .accessibilityLabel("Target wake time")
                    .accessibilityHint("Set your preferred wake up time")
                    .accessibilityIdentifier("targetWakeTimePicker")
            }
        } footer: {
            if sleepGoalEnabled {
                Text("Your target sleep duration: \(formattedSleepDuration)")
                    .font(.caption)
                    .accessibilityLabel("Your target sleep duration is \(formattedSleepDuration)")
                    .accessibilityIdentifier("targetDurationFooter")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sleepGoalSectionContainer")
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
                    .accessibilityLabel("\(Calendar.current.weekdaySymbols[index]) sleep goal")
                    .accessibilityHint(selectedDays.contains(index) ? "Sleep goal is enabled for \(Calendar.current.weekdaySymbols[index])" : "Sleep goal is disabled for \(Calendar.current.weekdaySymbols[index])")
                    .accessibilityIdentifier("dayToggle_\(index)")
            }
        } header: {
            Text("Schedule")
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("scheduleHeader")
        } footer: {
            Text("Your sleep goal will be active on selected days")
                .accessibilityLabel("Sleep goal will be active on the days you have selected")
                .accessibilityIdentifier("scheduleFooter")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("scheduleSectionContainer")
    }
    
    private var recommendationsSection: some View {
        Section {
            Button(action: { showingRecommendations = true }) {
                HStack {
                    Image(systemName: "lightbulb")
                        .foregroundColor(.yellow)
                        .accessibilityHidden(true)
                    Text("Get Personalized Recommendations")
                }
            }
            .accessibilityLabel("Get personalized sleep recommendations")
            .accessibilityHint("View sleep recommendations based on your personal profile and history")
            .accessibilityIdentifier("recommendationsButton")
        } footer: {
            Text("Based on your age, activity level, and sleep history")
                .accessibilityLabel("Recommendations are based on your age, activity level, and sleep history")
                .accessibilityIdentifier("recommendationsFooter")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("recommendationsSectionContainer")
    }
    
    private var calculatedMetricsSection: some View {
        Section {
            HStack {
                Text("Weekly Sleep Debt")
                Spacer()
                Text(calculateWeeklySleepDebt())
                    .foregroundColor(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Weekly sleep debt \(calculateWeeklySleepDebt())")
            .accessibilityHint("Recorded sleep duration below your selected goal during the past seven days")
            .accessibilityIdentifier("weeklySleepDebt")
            
            HStack {
                Text("Monthly Average")
                Spacer()
                Text(calculateMonthlyAverage())
                    .foregroundColor(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Monthly sleep average \(calculateMonthlyAverage())")
            .accessibilityHint("Your average sleep duration over the past month")
            .accessibilityIdentifier("monthlySleepAverage")
        } header: {
            Text("Calculated Metrics")
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("calculatedMetricsHeader")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("calculatedMetricsSectionContainer")
    }
    
    private var formattedSleepDuration: String {
        let duration = targetDuration
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        return String(format: "%dh %02dm", hours, minutes)
    }

    private var targetDuration: TimeInterval {
        SleepGoalPolicy.duration(from: targetBedtime, to: targetWakeTime)
    }
    
    private func savePreferences() {
        let context = viewContext
        let prefs = preferences.first ?? UserPreferences(context: context)
        
        prefs.id = prefs.id ?? UUID()
        prefs.sleepGoalEnabled = sleepGoalEnabled
        prefs.targetBedtime = targetBedtime
        prefs.targetWakeTime = targetWakeTime
        prefs.targetSleepDuration = targetDuration
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
        guard let summary = SleepDebtCalculator.shared.summary(context: viewContext),
              summary.coveredDayCount > 0 else {
            return "No data"
        }
        return formatDuration(summary.totalShortfall)
    }

    private func calculateMonthlyAverage() -> String {
        guard let summary = SleepDebtCalculator.shared.summary(forDays: 30, context: viewContext),
              summary.coveredDayCount > 0 else {
            return "No data"
        }
        return formatDuration(summary.averageComparedDuration)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration.rounded()) / 60
        return "\(minutes / 60)h \(minutes % 60)m"
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
