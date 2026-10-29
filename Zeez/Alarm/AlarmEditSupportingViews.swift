import SwiftUI
import os.log

struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
            }
            .foregroundColor(.purple)
            
            content
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settingsCard_\(title.lowercased().replacingOccurrences(of: " ", with: ""))")
    }
}

struct SchedulePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDays: Set<Int>
    
    private let weekdays = Calendar.current.weekdaySymbols
    private let presets: [(String, Set<Int>)] = [
        ("Every Day", Set(1...7)),
        ("Weekdays", Set(2...6)),
        ("Weekends", Set([1, 7]))
    ]
    
    var body: some View {
        NavigationStack {
            List {
                Section("Presets") {
                    ForEach(presets, id: \.0) { preset in
                        Button(action: { selectedDays = preset.1 }) {
                            HStack {
                                Text(preset.0)
                                Spacer()
                                if selectedDays == preset.1 {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.purple)
                                        .accessibilityHidden(true)
                                }
                            }
                        }
                        .accessibilityLabel("\(preset.0) schedule")
                        .accessibilityHint(selectedDays == preset.1 ? "Currently selected" : "Tap to select this schedule")
                        .accessibilityIdentifier("schedulePreset_\(preset.0.lowercased().replacingOccurrences(of: " ", with: ""))")
                    }
                }
                
                Section("Custom") {
                    ForEach(0..<7) { index in
                        let weekday = index + 1
                        Toggle(weekdays[index], isOn: binding(for: weekday))
                            .accessibilityLabel("\(weekdays[index])")
                            .accessibilityHint("Toggle alarm for \(weekdays[index])")
                            .accessibilityIdentifier("weekdayToggle_\(index)")
                    }
                }
            }
            .navigationTitle("Repeat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .accessibilityLabel("Done selecting schedule")
                        .accessibilityIdentifier("schedulePickerDone")
                }
            }
        }
    }
    
    private func binding(for weekday: Int) -> Binding<Bool> {
        Binding(
            get: { selectedDays.contains(weekday) },
            set: { isSelected in
                if isSelected {
                    selectedDays.insert(weekday)
                } else {
                    selectedDays.remove(weekday)
                }
            }
        )
    }
}
