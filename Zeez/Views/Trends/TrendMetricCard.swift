import SwiftUI
import Charts
import os.log

struct TrendMetricCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let value: String?
    let valueColor: Color
    @ViewBuilder let content: () -> Content
    
    init(
        title: String,
        subtitle: String? = nil,
        value: String? = nil,
        valueColor: Color = .primary,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.valueColor = valueColor
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                if let value = value {
                    Text(value)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(valueColor)
                }
            }
            
            content()
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                // systemBackground is the page's own color, so in dark mode the card vanished.
                .fill(Color(UIColor.secondarySystemBackground))
        }
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            VStack(spacing: 16) {
                TrendMetricCard(
                    title: "Sleep Quality",
                    subtitle: "Last 7 days",
                    value: "85%",
                    valueColor: .green
                ) {
                    Chart([0, 1, 2, 3, 4, 5, 6], id: \.self) { _ in
                        LineMark(
                            x: .value("Day", Double.random(in: 0...6)),
                            y: .value("Value", Double.random(in: 0...100))
                        )
                    }
                    .frame(height: 100)
                }
                .padding(.horizontal)
            }
        }
    }
}
