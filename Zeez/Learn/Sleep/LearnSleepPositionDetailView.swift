import SwiftUI
import os.log

struct LearnSleepPositionDetailView: View {
    let position: SleepPosition
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    positionHeader
                    
                    benefitsSection
                    
                    drawbacksSection
                    
                    recommendationsSection
                    
                    tipsSection
                }
                .padding()
            }
            .navigationTitle("\(position.rawValue) Position")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                    .accessibilityLabel("Close position details")
                    .accessibilityHint("Return to sleep positions overview")
                    .accessibilityIdentifier("closePositionDetailsButton")
                }
            }
        }
    }
    
    private var positionHeader: some View {
        HStack {
            Image(systemName: position.icon)
                .font(.system(size: 40))
                .rotationEffect(.degrees(
                    position == .rightSide ? 90 :
                    position == .leftSide ? -90 :
                    position == .stomach ? 180 : 0
                ))
                .accessibilityLabel("\(position.rawValue) position icon")
            
            VStack(alignment: .leading) {
                Text(position.rawValue)
                    .font(.headline)
                Text(getPositionDescription())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(position.rawValue) position. \(getPositionDescription())")
        .accessibilityIdentifier("positionHeader")
    }
    
    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Benefits")
                .font(.headline)
                .accessibilityLabel("Benefits section")
            
            ForEach(position.benefits, id: \.self) { benefit in
                Label(benefit, systemImage: "checkmark.circle")
                    .foregroundColor(.green)
                    .accessibilityLabel("Benefit: \(benefit)")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("benefitsSection")
    }
    
    private var drawbacksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Potential Drawbacks")
                .font(.headline)
                .accessibilityLabel("Potential drawbacks section")
            
            ForEach(position.drawbacks, id: \.self) { drawback in
                Label(drawback, systemImage: "exclamationmark.circle")
                    .foregroundColor(.orange)
                    .accessibilityLabel("Drawback: \(drawback)")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("drawbacksSection")
    }
    
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Best For")
                .font(.headline)
                .accessibilityLabel("Best for section")
            
            ForEach(getPositionRecommendations(), id: \.self) { recommendation in
                Label(recommendation, systemImage: "person.fill")
                    .accessibilityLabel("Best for: \(recommendation)")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("recommendationsSection")
    }
    
    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Optimization Tips")
                .font(.headline)
                .accessibilityLabel("Optimization tips section")
            
            ForEach(getOptimizationTips(), id: \.self) { tip in
                Label(tip, systemImage: "lightbulb")
                    .foregroundColor(.blue)
                    .accessibilityLabel("Tip: \(tip)")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("tipsSection")
    }
    
    private func getPositionDescription() -> String {
        switch position {
        case .back:
            return "Considered the healthiest sleeping position"
        case .leftSide:
            return "Beneficial for digestion and heart health"
        case .rightSide:
            return "Good alternative to left-side sleeping"
        case .stomach:
            return "Generally not recommended but comfortable for some"
        case .unknown:
            return "Unable to determine sleeping position"
        }
    }
    
    private func getPositionRecommendations() -> [String] {
        switch position {
        case .back:
            return [
                "People with back pain",
                "Those concerned about wrinkles",
                "Neck pain sufferers"
            ]
        case .leftSide:
            return [
                "People with acid reflux",
                "Pregnant individuals",
                "Those with heart conditions"
            ]
        case .rightSide:
            return [
                "People with shoulder pain",
                "Those with lower back pain",
                "Individuals with breathing issues"
            ]
        case .stomach:
            return [
                "Heavy snorers",
                "Sleep apnea sufferers",
                "Those who find it naturally comfortable"
            ]
        case .unknown:
            return [
                "Position cannot be determined",
                "May need better sensor positioning",
                "Consider manual position tracking"
            ]
        }
    }
    
    private func getOptimizationTips() -> [String] {
        switch position {
        case .back:
            return [
                "Use a medium-firm pillow",
                "Place small pillow under knees",
                "Keep head aligned with spine"
            ]
        case .leftSide:
            return [
                "Place pillow between knees",
                "Use body pillow for support",
                "Keep arms parallel to body"
            ]
        case .rightSide:
            return [
                "Use pillow between knees",
                "Choose supportive mattress",
                "Keep neck aligned with spine"
            ]
        case .stomach:
            return [
                "Use very thin pillow",
                "Place pillow under hips",
                "Turn head to different sides"
            ]
        case .unknown:
            return [
                "Position cannot be determined",
                "May need better sensor positioning",
                "Consider manual position tracking"
            ]
        }
    }
}

#Preview {
    LearnSleepPositionDetailView(position: .back)
}
