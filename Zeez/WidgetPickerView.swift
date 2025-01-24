import SwiftUI

struct WidgetPickerView: View {
    let availableWidgets: [WidgetType]
    let onWidgetSelected: (WidgetType) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(availableWidgets, id: \.self) { type in
                Button(action: {
                    onWidgetSelected(type)
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: type.systemImage)
                        
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
                    }
                }
            }
            .navigationTitle("Add Widget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
