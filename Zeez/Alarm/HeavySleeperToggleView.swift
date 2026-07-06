import SwiftUI
import os.log

/// A toggle view for enabling/disabling Heavy Sleeper mode
struct HeavySleeperToggleView: View {
    @ObservedObject var alarm: AlarmConfiguration
    @State private var isHeavySleeper: Bool
    @State private var snoozeDuration: Int
    
    private let snoozeDurationOptions = [1, 3, 5, 9, 10, 15, 20, 30]
    
    init(alarm: AlarmConfiguration) {
        self.alarm = alarm
        self._isHeavySleeper = State(initialValue: alarm.heavySleeperMode)
        self._snoozeDuration = State(initialValue: alarm.snoozeDurationMinutes)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Heavy Sleeper Mode Toggle
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Heavy Sleeper Mode")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("More frequent notifications for deeper sleepers")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $isHeavySleeper)
                    .onChange(of: isHeavySleeper) { _, newValue in
                        alarm.heavySleeperMode = newValue
                        saveChanges()
                    }
            }
            
            // Snooze Duration Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Snooze Duration")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    Text("When snoozed, alarm fires again after:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Picker("Snooze Duration", selection: $snoozeDuration) {
                        ForEach(snoozeDurationOptions, id: \.self) { minutes in
                            Text("\(minutes) min").tag(minutes)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: snoozeDuration) { _, newValue in
                        alarm.setSnoozeDuration(minutes: newValue)
                        saveChanges()
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
            
            // Heavy Sleeper Info
            if isHeavySleeper {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Follow-up notifications every 31 seconds")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Up to 20 follow-ups instead of 12")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Heavy Sleeper and Snooze Settings")
        .accessibilityValue("Heavy sleeper: \(isHeavySleeper ? "enabled" : "disabled"), Snooze: \(snoozeDuration) minutes")
        .accessibilityHint("Configure notification frequency and snooze duration")
    }
    
    private func saveChanges() {
        // Save the context if available
        if let context = alarm.managedObjectContext {
            do {
                try context.save()
                ZeezLogger.info(ZeezLogger.alarm, "Alarm settings updated and saved")
            } catch {
                ZeezLogger.error(ZeezLogger.alarm, "Error saving alarm settings", error: error)
            }
        }
        
        // Re-schedule the alarm to apply new settings
        if alarm.enabled {
            AlarmScheduler.shared.scheduleSpecificAlarm(alarm)
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let alarm = AlarmConfiguration(context: context)
    alarm.name = "Morning Alarm"
    alarm.enabled = true
    
    return VStack {
        HeavySleeperToggleView(alarm: alarm)
        Spacer()
    }
    .padding()
    .environment(\.managedObjectContext, context)
}