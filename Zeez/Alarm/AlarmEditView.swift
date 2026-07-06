import SwiftUI
import CoreData
import os.log

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
    
    // Gestures & Snooze
    @State private var snoozeGesture: String
    @State private var deactivateGesture: String
    @State private var snoozeDuration: Int16
    
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
        _alarmSound = State(initialValue: alarm?.alarmSound ?? "Alarm_Classic.caf")
        _alarmSoundSource = State(initialValue: alarm?.alarmSoundSource ?? "Classic Alarm")
        
        _vibrationOnly = State(initialValue: alarm?.vibrationOnly ?? false)
        _allowVibrationsWithSound = State(initialValue: alarm?.allowVibrationsWithSound ?? true)
        _watchHaptics = State(initialValue: alarm?.watchHaptics ?? true)
        
        _smartWakeEnabled = State(initialValue: alarm?.smartWakeEnabled ?? true)
        _smartWakeWindow = State(initialValue: alarm?.smartWakeWindow ?? 30)
        _audioCapture = State(initialValue: alarm?.audioCapture ?? false)
        
        _snoozeGesture = State(initialValue: alarm?.snoozeGesture ?? "tap")
        _deactivateGesture = State(initialValue: alarm?.deactivateGesture ?? "long_press")
        _snoozeDuration = State(initialValue: alarm?.snoozeDuration ?? 9)
        
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
                        .accessibilityLabel("Alarm name")
                        .accessibilityHint("Enter a name for this alarm")
                        .accessibilityIdentifier("alarmNameField")
                    
                    VStack(spacing: 8) {
                        Button(action: { withAnimation { showTimePicker.toggle() } }) {
                            VStack(spacing: 8) {
                                Text("Wake up at")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Text(timeString)
                                    .font(.system(.largeTitle, design: .rounded, weight: .medium))
                                
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.secondary)
                                    .rotationEffect(.degrees(showTimePicker ? -180 : 0))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Wake up time: \(timeString)")
                        .accessibilityHint(showTimePicker ? "Close time picker" : "Open time picker to change alarm time")
                        .accessibilityIdentifier("alarmTimeButton")
                        
                        if showTimePicker {
                            DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                                .accessibilityLabel("Select alarm time")
                                .accessibilityHint("Use the wheels to set hours and minutes for your alarm")
                                .accessibilityIdentifier("alarmTimePicker")
                        }
                    }
                }
                .padding()
                
                // Settings Cards
                VStack(spacing: 2) {
                    scheduleCard
                    smartWakeCard
                    heavySleeperCard
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
                    .accessibilityLabel("Delete alarm")
                    .accessibilityHint("Warning: This permanently removes the alarm")
                    .accessibilityIdentifier("deleteAlarmButton")
                }
            }
        }
        .navigationTitle(alarm == nil ? "Add Alarm" : "Edit Alarm")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") { saveAlarm() }
                    .accessibilityLabel("Save alarm")
                    .accessibilityHint("Save the alarm with current settings")
                    .accessibilityIdentifier("saveAlarmButton")
            }
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
            Button(action: { showSchedulePicker = true }) {
                HStack {
                    Text(schedulePresetString)
                        .foregroundColor(selectedDays.isEmpty ? .secondary : .primary)
                    Spacer()
                    if !selectedDays.isEmpty {
                        WeekdayCircles(selectedDays: selectedDays)
                            .foregroundColor(.blue)
                    }
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Schedule: \(schedulePresetString)")
            .accessibilityHint("Configure which days this alarm will be active")
            .accessibilityIdentifier("scheduleButton")
        }
        .sheet(isPresented: $showSchedulePicker) {
            SchedulePickerView(selectedDays: $selectedDays)
        }
        .sheet(isPresented: $showSoundPicker) {
            AlarmSoundPickerView(selectedSound: $alarmSound)
        }
    }

    private var schedulePresetString: String {
        if selectedDays.isEmpty {
            return "Never"
        } else if selectedDays.count == 7 {
            return "Every day"
        } else if selectedDays.count == 5 && !selectedDays.contains(1) && !selectedDays.contains(7) {
            return "Weekdays"
        } else if selectedDays.count == 2 && selectedDays.contains(1) && selectedDays.contains(7) {
            return "Weekends"
        } else {
            return "Custom"
        }
    }
    
    private struct WeekdayCircles: View {
        let selectedDays: Set<Int>
        
        private let weekdays = ["S", "M", "T", "W", "T", "F", "S"]
        
        var body: some View {
            HStack(spacing: 4) {
                ForEach(1...7, id: \.self) { day in
                    ZStack {
                        Circle()
                            .fill(selectedDays.contains(day) ? Color.blue : Color.clear)
                            .frame(width: 20, height: 20)
                        
                        Circle()
                            .strokeBorder(selectedDays.contains(day) ? Color.blue : Color.gray, lineWidth: 1)
                            .frame(width: 20, height: 20)
                        
                        Text(weekdays[day - 1])
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(selectedDays.contains(day) ? .white : .gray)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    @State private var isWakeWindowExpanded = false
    
    private var smartWakeCard: some View {
        SettingsCard(title: "Gentle Pre-Alarm", icon: "sparkles") {
            VStack(alignment: .leading, spacing: 16) {
                Toggle("Enable Gentle Pre-Alarm", isOn: $smartWakeEnabled)
                
                if smartWakeEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Button(action: { withAnimation { isWakeWindowExpanded.toggle() } }) {
                            HStack {
                                Text("Wake Window")
                                Spacer()
                                Text("\(smartWakeWindow) minutes before alarm")
                                    .foregroundColor(.secondary)
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.secondary)
                                    .rotationEffect(.degrees(isWakeWindowExpanded ? -180 : 0))
                            }
                        }
                        
                        if isWakeWindowExpanded {
                            Picker("Wake Window", selection: $smartWakeWindow) {
                                ForEach(smartWakeWindows, id: \.self) { minutes in
                                    Text("\(minutes) minutes before alarm")
                                        .tag(Int16(minutes))
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(height: 120)
                        }
                    }
                    
                    Text("Get an earlier, quieter alert up to the selected number of minutes before your alarm")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Toggle("Record Sleep Audio", isOn: $audioCapture)
                }
            }
        }
    }
    
    private var soundCard: some View {
        SettingsCard(title: "Sound & Music", icon: "speaker.wave.2") {
            VStack(alignment: .leading, spacing: 16) {
                if !vibrationOnly {
                    Button(action: { showSoundPicker = true }) {
                        HStack {
                            Text("Alarm Sound")
                            Spacer()
                            Text(getSoundDisplayName(alarmSound))
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                    .accessibilityLabel("Alarm sound")
                    .accessibilityValue(getSoundDisplayName(alarmSound))
                    .accessibilityHint("Tap to choose a different alarm sound")
                    
                    VStack {
                        HStack {
                            Image(systemName: "speaker.fill")
                                .foregroundColor(vibrationOnly ? .secondary : .primary)
                            Slider(value: $musicVolume)
                                .disabled(vibrationOnly)
                            Image(systemName: "speaker.wave.3.fill")
                                .foregroundColor(vibrationOnly ? .secondary : .primary)
                        }
                    }
                }
                
                Toggle("Vibration Only", isOn: Binding(
                    get: { vibrationOnly },
                    set: { newValue in
                        vibrationOnly = newValue
                        if newValue {
                            // When vibration only is enabled, set volume to 0
                            musicVolume = 0
                            allowVibrationsWithSound = false
                        }
                    }
                ))
                
                if !vibrationOnly {
                    Toggle("Allow Vibrations with Sound", isOn: $allowVibrationsWithSound)
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
            Toggle("Show on Apple Watch", isOn: $watchHaptics)
        }
    }
    
    private var heavySleeperCard: some View {
        SettingsCard(title: "Heavy Sleeper", icon: "zzz") {
            if let alarm = alarm {
                HeavySleeperToggleView(alarm: alarm)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Heavy Sleeper Mode")
                        .font(.headline)
                    Text("More frequent notifications for deeper sleepers")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Available after creating the alarm")
                        .font(.caption)
                        .foregroundColor(.orange)
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
    
    private func getSoundDisplayName(_ soundId: String) -> String {
        let allSounds = AlarmSounds.getAllSounds()
        return allSounds.first { $0.id == soundId }?.name ?? "Default"
    }
    
    private func saveAlarm() {
        // Check if enabling an alarm but notifications are denied
        if enabled {
            AlarmPermissionManager.shared.requestPermissionsWithExplainer { granted in
                if !granted {
                    // Post notification to show denied permission flow
                    NotificationCenter.default.post(name: NSNotification.Name("AlarmPermissionDenied"), object: nil)
                    return
                }
                // Permissions granted, proceed with save
                performSave()
            }
        } else {
            // Just saving without enabling, no permission check needed
            performSave()
        }
    }
    
    private func performSave() {
        let alarmToSave = alarm ?? AlarmConfiguration(context: viewContext)
        let isNewAlarm = alarm == nil
        
        // Debug logging before save
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        ZeezLogger.info(ZeezLogger.alarm, "💾 Saving alarm '\(name)' - Time: \(timeFormatter.string(from: time)), Enabled: \(enabled)")
        
        if !isNewAlarm {
            ZeezLogger.debug(ZeezLogger.alarm, "   Previous time was: \(timeFormatter.string(from: alarmToSave.time ?? Date()))")
        }
        
        alarmToSave.id = alarmToSave.id ?? UUID()
        // Ensure we have a valid name
        alarmToSave.name = name.isEmpty ? "Alarm" : name
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
        alarmToSave.snoozeDuration = snoozeDuration
        alarmToSave.modifiedAt = Date()
        
        if let encodedDays = try? JSONEncoder().encode(selectedDays) {
            alarmToSave.daysOfWeek = encodedDays
        }
        
        if alarm == nil {
            alarmToSave.createdAt = Date()
        }
        
        do {
            try viewContext.save()
            
            // Log successful save and scheduling
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "h:mm a"
            let timeString = timeFormatter.string(from: time)
            
            ZeezLogger.info(ZeezLogger.alarm, "✅ Successfully \(isNewAlarm ? "created" : "updated") alarm '\(name)' for \(timeString)")
            
            // Check notification permissions to provide user feedback
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                DispatchQueue.main.async {
                    if settings.authorizationStatus != .authorized {
                        ZeezLogger.error(ZeezLogger.alarm, "Alarm saved but notifications not permitted - alarm will not function")
                    } else {
                        ZeezLogger.info(ZeezLogger.alarm, "Alarm scheduled successfully")
                    }
                }
            }
            
            dismiss()
        } catch {
            ZeezLogger.error(ZeezLogger.alarm, "Failed to save alarm", error: error)
            // Could show error alert to user in production
        }
    }
    
    private func deleteAlarm() {
        if let alarm = alarm {
            viewContext.delete(alarm)
            do {
                try viewContext.save()
                dismiss()
            } catch {
                ZeezLogger.error(ZeezLogger.alarm, "Failed to delete alarm", error: error)
                // Could show error alert to user in production
            }
        } else {
            dismiss()
        }
    }
}

#Preview("New Alarm") {
    NavigationView {
        AlarmEditView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}

#Preview("Edit Alarm") {
    let context = PersistenceController.preview.container.viewContext
    let alarm = AlarmConfiguration(context: context)
    alarm.name = "Morning Alarm"
    alarm.time = Date()
    alarm.enabled = true
    alarm.smartWakeEnabled = true
    alarm.smartWakeWindow = 30
    alarm.audioCapture = true
    alarm.vibrationOnly = false
    alarm.watchHaptics = true
    
    return NavigationView {
        AlarmEditView(alarm: alarm)
            .environment(\.managedObjectContext, context)
    }
}
