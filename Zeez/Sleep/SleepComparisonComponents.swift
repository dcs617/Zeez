import SwiftUI
import os.log

struct SleepComparisonView: View {
    let current: TimeInterval
    let average: TimeInterval
    let goal: TimeInterval
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleep Time Comparison")
                .font(.headline)
            
            comparisonBars
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(UIColor.secondarySystemBackground))
        }
    }
    
    private var comparisonBars: some View {
        HStack(spacing: 20) {
            ComparisonBar(value: current, label: "Current", color: .blue)
            ComparisonBar(value: average, label: "Average", color: .gray)
            ComparisonBar(value: goal, label: "Goal", color: .green)
        }
        .frame(height: 150)
    }
}

private struct ComparisonBar: View {
    let value: TimeInterval
    let label: String
    let color: Color
    
    var body: some View {
        VStack {
            barView
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private var barView: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(color.opacity(0.2))
                .frame(height: 120)
            
            Rectangle()
                .fill(color)
                .frame(height: barHeight)
        }
        .cornerRadius(8)
    }
    
    private var barHeight: CGFloat {
        let maxHeight: CGFloat = 120
        let maxHours: TimeInterval = AppConstants.Sleep.chartMaxHours
        return CGFloat(min(value / maxHours, 1.0)) * maxHeight
    }
}
