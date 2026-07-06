import SwiftUI
import CoreData
import UserNotifications
import os.log

struct AlarmSettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest<AlarmConfiguration>(
        sortDescriptors: [NSSortDescriptor(keyPath: \AlarmConfiguration.time, ascending: true)],
        animation: .default
    ) private var alarms
    
    @State private var showingNewAlarm = false
    @State private var selectedAlarm: AlarmConfiguration?
    @State private var selectedSortOption: AlarmSortOption = .time
    @State private var notificationBudget: NotificationBudget?
    
    private var alarmArray: [AlarmConfiguration] {
        selectedSortOption.sortAlarms(Array(alarms))
    }
    
    private var activeAlarms: [AlarmConfiguration] {
        alarmArray.filter { $0.enabled }
    }
    
    private var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Always show NextAlarmSummary
                    NextAlarmSummary(alarms: activeAlarms)
                        .padding(.horizontal)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Next Alarm Summary")
                        .accessibilityHint("Shows details about your next scheduled alarm")

                    if let budget = notificationBudget, budget.isNearCap {
                        notificationBudgetWarning(budget)
                            .padding(.horizontal)
                    }

                    if alarmArray.isEmpty {
                        emptyStateView
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("No alarms scheduled")
                            .accessibilityHint("Tap the plus button to add your first alarm")
                    } else {
                        allAlarmsSection
                    }
                }
                .padding(.bottom, 100) // Space for FAB
            }
            
            // Floating Action Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    addAlarmButton
                        .padding(.trailing)
                        .padding(.bottom)
                }
            }
        }
        .navigationTitle("Rise")
        .sheet(isPresented: $showingNewAlarm) {
            NavigationView {
                AlarmEditView()
            }
        }
        .sheet(item: $selectedAlarm) { alarm in
            NavigationView {
                AlarmEditView(alarm: alarm)
            }
        }
        .onAppear { refreshNotificationBudget() }
        .onChange(of: alarms.count) { _, _ in refreshNotificationBudget() }
    }

    // MARK: - Notification budget (roadmap 1.4)

    private func refreshNotificationBudget() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let budget = NotificationBudget(requests: requests)
            DispatchQueue.main.async {
                notificationBudget = budget
            }
        }
    }

    private func notificationBudgetWarning(_ budget: NotificationBudget) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text("Many alarms scheduled")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("You have many alarms and follow-up reminders scheduled (\(budget.total) of \(NotificationBudget.systemCap)). iOS may not deliver some follow-up reminders — consider disabling alarms you don't use.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Notification limit warning")
        .accessibilityHint("You have \(budget.total) of \(NotificationBudget.systemCap) possible scheduled notifications. Some follow-up reminders may not fire.")
    }
    
    private var allAlarmsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("ALL ALARMS")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Menu {
                    Picker("Sort By", selection: $selectedSortOption) {
                        ForEach(AlarmSortOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedSortOption.rawValue)
                            .font(.subheadline)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                    }
                    .foregroundColor(.purple)
                }
                .accessibilityLabel("Sort alarms by \(selectedSortOption.rawValue)")
                .accessibilityHint("Opens menu to change alarm sorting order")
                .accessibilityIdentifier("alarmSortMenu")
            }
            .padding(.horizontal)
            
            VStack(spacing: 2) {
                ForEach(alarmArray) { alarm in
                    AlarmRow(alarm: alarm) {
                        selectedAlarm = alarm
                    }
                    .padding(.horizontal)
                    .contentShape(Rectangle())
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Alarm for \(alarm.time != nil ? timeFormatter.string(from: alarm.time!) : "unknown time"), \(alarm.enabled ? "enabled" : "disabled")")
                    .accessibilityHint("Double tap to edit alarm, swipe left to delete")
                    .accessibilityIdentifier("alarmRow_\(alarm.objectID)")
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            deleteAlarm(alarm)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .accessibilityLabel("Delete alarm")
                        .accessibilityHint("Permanently removes this alarm")
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No alarms scheduled")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Tap + to add your first alarm")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var addAlarmButton: some View {
        Button(action: { showingNewAlarm = true }) {
            Image(systemName: "plus")
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Color.purple)
                .clipShape(Circle())
                .shadow(radius: 4, y: 2)
        }
        .accessibilityLabel("Add new alarm")
        .accessibilityHint("Opens alarm creation screen to set up a new alarm")
        .accessibilityIdentifier("addAlarmButton")
    }
    
    private func deleteAlarm(_ alarm: AlarmConfiguration) {
        withAnimation {
            viewContext.delete(alarm)
            try? viewContext.save()
        }
    }
}

#Preview {
    NavigationView {
        AlarmSettingsView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
