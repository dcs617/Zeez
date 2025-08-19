import SwiftUI
import os.log

struct WidgetPickerView: View {
    let availableWidgets: [WidgetType]
    let onWidgetSelected: (WidgetType) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(Array(availableWidgets.enumerated()), id: \.element) { index, type in
                Button(action: {
                    onWidgetSelected(type)
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: type.systemImage)
                            .accessibilityHidden(true)
                        
                        VStack(alignment: .leading) {
                            Text(type.rawValue)
                                .font(.headline)
                            
                            if type.requiresPremium {
                                Text("Premium")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "plus.circle")
                            .foregroundColor(.blue)
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Add \(type.rawValue) widget\(type.requiresPremium ? ", premium feature" : "")")
                .accessibilityHint("Tap to add this widget to your dashboard")
                .accessibilityIdentifier("widgetOption_\(index)")
            }
            .navigationTitle("Add Widget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityLabel("Close widget picker")
                    .accessibilityIdentifier("doneButton")
                }
            }
        }
        .accessibilityIdentifier("widgetPickerView")
    }
}
