import SwiftUI
import CoreData

struct AlarmEditView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    // Optional alarm for editing existing alarms
    var alarm: AlarmConfiguration?
    
    @State private var time: Date
    @State private var enabled: Bool
    @State private var smartWakeEnabled: Bool
    @State private var vibrationOnly: Bool
    
    init(alarm: AlarmConfiguration? = nil) {
        self.alarm = alarm
        _time = State(initialValue: alarm?.time ?? Date())
        _enabled = State(initialValue: alarm?.enabled ?? true)
        _smartWakeEnabled = State(initialValue: alarm?.smartWakeEnabled ?? true)
        _vibrationOnly = State(initialValue: alarm?.vibrationOnly ?? false)
    }
    
    var body: some View {
        Form {
            Section {
                DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            
            Section {
                Toggle("Enabled", isOn: $enabled)
                Toggle("Smart Wake", isOn: $smartWakeEnabled)
                Toggle("Vibration Only", isOn: $vibrationOnly)
            }
        }
        .navigationTitle(alarm == nil ? "Add Alarm" : "Edit Alarm")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveAlarm()
                }
            }
        }
    }
    
    private func saveAlarm() {
        let alarmToSave = alarm ?? AlarmConfiguration(context: viewContext)
        
        alarmToSave.id = alarmToSave.id ?? UUID()
        alarmToSave.time = time
        alarmToSave.enabled = enabled
        alarmToSave.smartWakeEnabled = smartWakeEnabled
        alarmToSave.vibrationOnly = vibrationOnly
        alarmToSave.modifiedAt = Date()
        
        if alarm == nil {
            alarmToSave.createdAt = Date()
        }
        
        try? viewContext.save()
        dismiss()
    }
}