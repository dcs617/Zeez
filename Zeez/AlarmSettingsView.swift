import SwiftUI
import CoreData

/// View for managing alarm configurations
/// Allows users to create, edit, and delete alarms with
/// smart wake and snooze preferences
struct AlarmSettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \AlarmConfiguration.time,
                                         ascending: true)],
        animation: .default
    ) private var alarms: FetchedResults<AlarmConfiguration>
    
    @State private var showingNewAlarm = false
    
    var body: some View {
        List {
            ForEach(alarms) { alarm in
                AlarmRow(alarm: alarm)
            }
            .onDelete(perform: deleteAlarms)
            
            addAlarmButton
        }
        .navigationTitle("Alarms")
        .sheet(isPresented: $showingNewAlarm) {
            NavigationView {
                AlarmEditView()
            }
        }
    }
    
    private var addAlarmButton: some View {
        Button(action: { showingNewAlarm = true }) {
            Label("Add Alarm", systemImage: "plus.circle.fill")
        }
    }
    
    private func deleteAlarms(offsets: IndexSet) {
        withAnimation {
            offsets.map { alarms[$0] }.forEach(viewContext.delete)
            try? viewContext.save()
        }
    }
}

/// Single alarm row displaying time and status
private struct AlarmRow: View {
    @ObservedObject var alarm: AlarmConfiguration
    @State private var showingEdit = false
    
    var body: some View {
        HStack {
            Toggle(isOn: binding(\.enabled)) {
                if let time = alarm.time {
                    Text(time, formatter: FormatterUtils.timeFormatter)
                        .font(.title2)
                }
            }
            
            Spacer()
            
            Button(action: { showingEdit = true }) {
                Image(systemName: "pencil.circle.fill")
                    .foregroundColor(.accentColor)
            }
        }
        .sheet(isPresented: $showingEdit) {
            NavigationView {
                AlarmEditView(alarm: alarm)
            }
        }
    }
    
    private func binding<T>(
        _ keyPath: ReferenceWritableKeyPath<AlarmConfiguration, T>
    ) -> Binding<T> {
        Binding(
            get: { alarm[keyPath: keyPath] },
            set: { newValue in
                alarm[keyPath: keyPath] = newValue
                try? alarm.managedObjectContext?.save()
            }
        )
    }
}