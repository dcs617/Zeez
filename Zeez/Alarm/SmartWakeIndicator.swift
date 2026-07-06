import SwiftUI
import os.log

/// Visual indicator for the gentle pre-alarm window
struct SmartWakeIndicator: View {
    let window: Int16
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Image(systemName: "waveform.path")
                .foregroundColor(.purple)
            
            Text("\(window)m window")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}
