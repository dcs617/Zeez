import SwiftUI
import CoreData

struct AlarmRow: View {
    @ObservedObject var alarm: AlarmConfiguration
    let onTap: () -> Void
    
    private var selectedDays: Set<Int> {
        guard let daysData = alarm.daysOfWeek,
              let days = try? JSONDecoder().decode(Set<Int>.self, from: daysData) else {
            return []
        }
        return days
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Time and Details
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 4) {
                    if let time = alarm.time {
                        Text(time, formatter: FormatterUtils.timeFormatter)
                            .font(.system(.title2, design: .rounded))
                            .foregroundColor(alarm.enabled ? .primary : .secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        if let name = alarm.name, !name.isEmpty {
                            Text(name)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        if !selectedDays.isEmpty {
                            Text(AlarmScheduleFormatter.format(selectedDays))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Features Indicators
            if alarm.enabled {
                featureIndicators
            }
            
            // Toggle
            Toggle("", isOn: Binding(
                get: { alarm.enabled },
                set: { newValue in
                    alarm.enabled = newValue
                    try? alarm.managedObjectContext?.save()
                }
            ))
            .labelsHidden()
            .tint(.purple)
        }
        .opacity(alarm.enabled ? 1.0 : 0.6)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 1, y: 1)
        )
    }
    
    private var featureIndicators: some View {
        HStack(spacing: 8) {
            if alarm.smartWakeEnabled {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundColor(.purple)
            }
            
            if alarm.vibrationOnly {
                Image(systemName: "iphone.radiowaves.left.and.right")
                    .font(.caption)
                    .foregroundColor(.purple)
            }
            
            if alarm.audioCapture {
                Image(systemName: "waveform")
                    .font(.caption)
                    .foregroundColor(.purple)
            }
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let alarm = AlarmConfiguration(context: context)
    alarm.time = Date()
    alarm.enabled = true
    alarm.name = "Morning Alarm"
    alarm.smartWakeEnabled = true
    alarm.vibrationOnly = true
    
    return AlarmRow(alarm: alarm) {}
        .padding()
        .previewLayout(.sizeThatFits)
}
