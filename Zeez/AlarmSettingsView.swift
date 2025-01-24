import SwiftUI
import CoreData

struct AlarmSettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest<AlarmConfiguration>(
        sortDescriptors: [NSSortDescriptor(keyPath: \AlarmConfiguration.time, ascending: true)],
        animation: .default
    ) private var alarms
    
    @State private var showingNewAlarm = false
    @State private var selectedAlarm: AlarmConfiguration?
    @State private var selectedSortOption: AlarmSortOption = .time
    
    private var alarmArray: [AlarmConfiguration] {
        selectedSortOption.sortAlarms(Array(alarms))
    }
    
    private var activeAlarms: [AlarmConfiguration] {
        alarmArray.filter { $0.enabled }
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    if !activeAlarms.isEmpty {
                        NextAlarmSummary(alarms: activeAlarms)
                            .padding(.horizontal)
                    }
                    
                    // All Alarms Section
                    if !alarmArray.isEmpty {
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
            }
            .padding(.horizontal)
            
            VStack(spacing: 2) {
                ForEach(alarmArray) { alarm in
                    AlarmRow(alarm: alarm) {
                        selectedAlarm = alarm
                    }
                    .padding(.horizontal)
                    .contentShape(Rectangle())
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            deleteAlarm(alarm)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
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