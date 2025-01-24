import SwiftUI

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
                Text(title)
                    .font(.headline)
            }
            .foregroundColor(.purple)
            
            content
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }
}

struct TimePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var time: Date
    
    init(time: Binding<Date>) {
        _time = time
        _tempTime = State(initialValue: time.wrappedValue)
    }
    
    @State private var tempTime: Date
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text(timeString)
                    .font(.system(size: 54, weight: .medium, design: .rounded))
                    .padding(.top, 32)
                
                DatePicker("Select Time", selection: $tempTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        time = tempTime
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: tempTime)
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
        NavigationView {
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
                                }
                            }
                        }
                    }
                }
                
                Section("Custom") {
                    ForEach(0..<7) { index in
                        let weekday = index + 1
                        Toggle(weekdays[index], isOn: binding(for: weekday))
                    }
                }
            }
            .navigationTitle("Repeat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
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

#Preview {
    TimePickerView(time: .constant(Date()))
}