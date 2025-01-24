import SwiftUI
import CoreData

import SwiftUI
import CoreData

struct AlarmEditView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    var alarm: AlarmConfiguration?
    
    // Basic Settings
    @State private var name: String
    @State private var time: Date
    @State private var enabled: Bool
    @State private var wakeType: String
    @State private var timerDuration: Int16
    @State private var showTimePicker = false
    
    // Schedule
    @State private var selectedDays: Set<Int>
    @State private var showSchedulePicker = false
    
    // Sound & Haptics
    @State private var musicEnabled: Bool
    @State private var musicSource: String
    @State private var musicVolume: Double
    @State private var alarmSound: String
    @State private var alarmSoundSource: String
    @State private var showSoundPicker = false
    @State private var vibrationOnly: Bool
    @State private var allowVibrationsWithSound: Bool
    @State private var watchHaptics: Bool
    
    // Smart Wake & Recording
    @State private var smartWakeEnabled: Bool
    @State private var smartWakeWindow: Int16
    @State private var audioCapture: Bool
    
    // Gestures
    @State private var snoozeGesture: String
    @State private var deactivateGesture: String
    
    private let wakeTypes = ["Time", "Timer"]
    private let weekdays = Calendar.current.weekdaySymbols
    private let smartWakeWindows = [15, 20, 25, 30, 35, 40, 45]
    
    init(alarm: AlarmConfiguration? = nil) {
        self.alarm = alarm
        
        // Initialize with existing alarm values or defaults
        _name = State(initialValue: alarm?.name ?? "")
        _time = State(initialValue: alarm?.time ?? Date())
        _enabled = State(initialValue: alarm?.enabled ?? true)
        _wakeType = State(initialValue: alarm?.wakeType ?? "Time")
        _timerDuration = State(initialValue: alarm?.timerDuration ?? 30)
        
        _musicEnabled = State(initialValue: alarm?.musicEnabled ?? false)
        _musicSource = State(initialValue: alarm?.musicSource ?? "Dream")
        _musicVolume = State(initialValue: alarm?.musicVolume ?? 0.5)
        _alarmSound = State(initialValue: alarm?.alarmSound ?? "default")
        _alarmSoundSource = State(initialValue: alarm?.alarmSoundSource ?? "Default")
        
        _vibrationOnly = State(initialValue: alarm?.vibrationOnly ?? false)
        _allowVibrationsWithSound = State(initialValue: alarm?.allowVibrationsWithSound ?? true)
        _watchHaptics = State(initialValue: alarm?.watchHaptics ?? true)
        
        _smartWakeEnabled = State(initialValue: alarm?.smartWakeEnabled ?? true)
        _smartWakeWindow = State(initialValue: alarm?.smartWakeWindow ?? 30)
        _audioCapture = State(initialValue: alarm?.audioCapture ?? false)
        
        _snoozeGesture = State(initialValue: alarm?.snoozeGesture ?? "tap")
        _deactivateGesture = State(initialValue: alarm?.deactivateGesture ?? "long_press")
        
        // Initialize selected days
        if let alarm = alarm,
           let daysData = alarm.daysOfWeek,
           let days = try? JSONDecoder().decode(Set<Int>.self, from: daysData) {
            _selectedDays = State(initialValue: days)
        } else {
            _selectedDays = State(initialValue: Set(1...7))
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Title and Time Section
                VStack(spacing: 16) {
                    TextField("Alarm Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.center)
                        .font(.headline)
                    
                    Button(action: { showTimePicker = true }) {
                        VStack(spacing: 8) {
                            Text("Wake up at")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text(timeString)
                                .font(.system(size: 48, weight: .medium, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                }
                .padding()
                
                // Settings Cards
                VStack(spacing: 2) {
                    scheduleCard
                    smartWakeCard
                    soundCard
                    gesturesCard
                    deviceSettingsCard
                }
                
                if alarm != nil {
                    Button(role: .destructive, action: deleteAlarm) {
                        Text("Delete Alarm")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding()
                }
            }
        }
        .navigationTitle(alarm == nil ? "Add Alarm" : "Edit Alarm")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") { saveAlarm() }
            }
        }
        .sheet(isPresented: $showTimePicker) {
            TimePickerView(time: $time)
        }
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: time)
    }
    
    // MARK: - Card Views
    
    private var scheduleCard: some View {
        SettingsCard(title: "Schedule", icon: "calendar") {
            let days = scheduleDaysString
            Button(action: { showSchedulePicker = true }) {
                HStack {
                    Text(days.isEmpty ? "Never" : days)
                        .foregroundColor(days.isEmpty ? .secondary : .primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
        }
        .sheet(isPresented: $showSchedulePicker) {
            SchedulePickerView(selectedDays: $selectedDays)
        }
    }
    
    private var smartWakeCard: some View {
        SettingsCard(title: "Smart Wake", icon: "sparkles") {
            VStack(alignment: .leading, spacing: 16) {
                Toggle("Enable Smart Wake", isOn: $smartWakeEnabled)
                
                if smartWakeEnabled {
                    Picker("Wake Window", selection: $smartWakeWindow) {
                        ForEach(smartWakeWindows, id: \.self) { minutes in
                            Text("\\(minutes) minutes").tag(Int16(minutes))
                        }
                    }
                }
                
                Toggle("Record Sleep Audio", isOn: $audioCapture)
            }
        }
    }
    
    private var soundCard: some View {
        SettingsCard(title: "Sound & Music", icon: "speaker.wave.2") {
            VStack(alignment: .leading, spacing: 16) {
                Button(action: { showSoundPicker = true }) {
                    HStack {
                        Text("Alarm Sound")
                        Spacer()
                        Text(alarmSound)
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                }
                
                VStack {
                    HStack {
                        Image(systemName: "speaker.fill")
                        Slider(value: $musicVolume)
                        Image(systemName: "speaker.wave.3.fill")
                    }
                }
            }
        }
    }
    
    private var gesturesCard: some View {
        SettingsCard(title: "Wake Up Actions", icon: "hand.tap") {
            NavigationLink {
                AlarmGesturePickerView(
                    selectedGesture: $snoozeGesture,
                    title: "Snooze Gesture",
                    isSnooze: true
                )
            } label: {
                HStack {
                    Text("Snooze Gesture")
                    Spacer()
                    Text(gestureDisplayName(snoozeGesture))
                        .foregroundColor(.secondary)
                }
            }
            
            NavigationLink {
                AlarmGesturePickerView(
                    selectedGesture: $deactivateGesture,
                    title: "Stop Alarm Gesture",
                    isSnooze: false
                )
            } label: {
                HStack {
                    Text("Stop Alarm Gesture")
                    Spacer()
                    Text(gestureDisplayName(deactivateGesture))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var deviceSettingsCard: some View {
        SettingsCard(title: "Device Settings", icon: "iphone") {
            VStack(alignment: .leading, spacing: 16) {
                Toggle("Show on Apple Watch", isOn: $watchHaptics)
                Toggle("Vibration Only", isOn: $vibrationOnly)
                if !vibrationOnly {
                    Toggle("Allow Vibrations with Sound", isOn: $allowVibrationsWithSound)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private var scheduleDaysString: String {
        if selectedDays.count == 7 {
            return "Every day"
        } else if selectedDays.count == 0 {
            return ""
        } else if selectedDays.count == 5 && !selectedDays.contains(1) && !selectedDays.contains(7) {
            return "Weekdays"
        } else if selectedDays.count == 2 && selectedDays.contains(1) && selectedDays.contains(7) {
            return "Weekends"
        } else {
            return selectedDays.sorted()
                .map { weekdays[$0 - 1].prefix(3) }
                .joined(separator: ", ")
        }
    }
    
    private func gestureDisplayName(_ gesture: String) -> String {
        switch gesture {
        case "tap": return "Single Tap"
        case "double_tap": return "Double Tap"
        case "long_press": return "Long Press"
        case "shake": return "Shake Device"
        case "flip": return "Flip Device"
        case "math": return "Solve Math Problem"
        case "type": return "Type Phrase"
        case "pattern": return "Draw Pattern"
        default: return "Unknown"
        }
    }
    
    private func saveAlarm() {
        let alarmToSave = alarm ?? AlarmConfiguration(context: viewContext)
        
        alarmToSave.id = alarmToSave.id ?? UUID()
        alarmToSave.name = name
        alarmToSave.time = time
        alarmToSave.enabled = enabled
        alarmToSave.wakeType = wakeType
        alarmToSave.timerDuration = timerDuration
        alarmToSave.smartWakeEnabled = smartWakeEnabled
        alarmToSave.smartWakeWindow = smartWakeWindow
        alarmToSave.audioCapture = audioCapture
        alarmToSave.musicEnabled = musicEnabled
        alarmToSave.musicSource = musicSource
        alarmToSave.musicVolume = musicVolume
        alarmToSave.alarmSound = alarmSound
        alarmToSave.alarmSoundSource = alarmSoundSource
        alarmToSave.vibrationOnly = vibrationOnly
        alarmToSave.allowVibrationsWithSound = allowVibrationsWithSound
        alarmToSave.watchHaptics = watchHaptics
        alarmToSave.snoozeGesture = snoozeGesture
        alarmToSave.deactivateGesture = deactivateGesture
        alarmToSave.modifiedAt = Date()
        
        if let encodedDays = try? JSONEncoder().encode(selectedDays) {
            alarmToSave.daysOfWeek = encodedDays
        }
        
        if alarm == nil {
            alarmToSave.createdAt = Date()
        }
        
        try? viewContext.save()
        dismiss()
    }
    
    private func deleteAlarm() {
        if let alarm = alarm {
            viewContext.delete(alarm)
            try? viewContext.save()
        }
        dismiss()
    }
}
