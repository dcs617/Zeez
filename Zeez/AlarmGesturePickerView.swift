import SwiftUI

struct AlarmGesturePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedGesture: String
    let title: String
    let isSnooze: Bool
    
    private let gestures = [
        "tap": "Single Tap",
        "double_tap": "Double Tap",
        "long_press": "Long Press",
        "shake": "Shake Device",
        "flip": "Flip Device",
        "math": "Solve Math Problem",
        "type": "Type Phrase",
        "pattern": "Draw Pattern"
    ]
    
    var body: some View {
        List {
            ForEach(Array(gestures.keys.sorted()), id: \.self) { key in
                Button(action: {
                    selectedGesture = key
                    dismiss()
                }) {
                    HStack {
                        Text(gestures[key] ?? "")
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if selectedGesture == key {
                            Image(systemName: "checkmark")
                                .foregroundColor(.purple)
                        }
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        AlarmGesturePickerView(
            selectedGesture: .constant("tap"),
            title: "Snooze Gesture",
            isSnooze: true
        )
    }
}