import SwiftUI
import Charts
import os.log

struct TrendMetricCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let value: String?
    let valueColor: Color
    let isPremium: Bool
    let requiredFeature: PremiumFeature?
    @ViewBuilder let content: () -> Content
    
    init(
        title: String,
        subtitle: String? = nil,
        value: String? = nil,
        valueColor: Color = .primary,
        isPremium: Bool = false,
        requiredFeature: PremiumFeature? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.valueColor = valueColor
        self.isPremium = isPremium
        self.requiredFeature = requiredFeature
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
            
            if isPremium {
                premiumContent
            } else {
                content()
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color(UIColor.systemBackground))
                .shadow(radius: 2)
        }
    }
    
    private var premiumContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.yellow)
            
            Text("Premium Feature")
                .font(.headline)
            
            Text("Upgrade to access detailed \(title.lowercased()) analytics and insights.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            NavigationLink(destination: SubscriptionView(requiredFeature: requiredFeature)) {
                Text("Upgrade to Premium")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.blue)
                    }
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    NavigationView {
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
                
                TrendMetricCard(
                    title: "Deep Sleep Analysis",
                    subtitle: "Premium feature",
                    isPremium: true,
                    requiredFeature: .detailedSleepStages
                ) {
                    EmptyView()
                }
                .padding(.horizontal)
            }
        }
    }
}
