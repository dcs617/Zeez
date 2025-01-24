import SwiftUI

struct StageComparisonDetailView: View {
    let metric: LearnSleepStageComparisonView.ComparisonMetric
    @Environment(\.dismiss) private var dismiss

    struct FunctionItem: Hashable {
        let text: String
        let icon: String
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(text)
            hasher.combine(icon)
        }
        
        static func == (lhs: FunctionItem, rhs: FunctionItem) -> Bool {
            lhs.text == rhs.text && lhs.icon == rhs.icon
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    factorHeader
                    
                    Divider()
                    
                    functionSection
                    
                    Divider()
                    
                    benefitsSection
                }
                .padding()
            }
            .navigationTitle("\(metric.rawValue) Comparison")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private var factorHeader: some View {
        HStack {
            Text(metric.rawValue)
                .font(.headline)
            Text(metric.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var functionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Primary Functions")
                .font(.headline)
            
            ForEach(getFunctions(), id: \.self) { item in
                Label(item.text, systemImage: item.icon)
                    .font(.subheadline)
            }
        }
    }
    
    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Health Benefits")
                .font(.headline)
            
            ForEach(getBenefits(), id: \.self) { benefit in
                Label(benefit, systemImage: "checkmark.circle")
                    .font(.subheadline)
                    .foregroundColor(.green)
            }
        }
    }
    
    private func getFunctions() -> [FunctionItem] {
        switch metric {
        case .brainActivity:
            return [
                FunctionItem(text: "Neural pathway maintenance", icon: "brain"),
                FunctionItem(text: "Memory consolidation", icon: "archivebox"),
                FunctionItem(text: "Cognitive processing", icon: "gear")
            ]
        case .bodyMovement:
            return [
                FunctionItem(text: "Physical restoration", icon: "figure.walk"),
                FunctionItem(text: "Muscle recovery", icon: "heart"),
                FunctionItem(text: "Energy conservation", icon: "bolt")
            ]
        case .memoryProcessing:
            return [
                FunctionItem(text: "Learning enhancement", icon: "book"),
                FunctionItem(text: "Skill development", icon: "hammer"),
                FunctionItem(text: "Knowledge integration", icon: "link")
            ]
        case .energyRestoration:
            return [
                FunctionItem(text: "Physical repair", icon: "bandage"),
                FunctionItem(text: "Immune function", icon: "shield"),
                FunctionItem(text: "Hormonal balance", icon: "atom")
            ]
        }
    }
    
    private func getBenefits() -> [String] {
        switch metric {
        case .brainActivity:
            return [
                "Enhanced cognitive performance",
                "Better problem-solving ability",
                "Improved memory recall"
            ]
        case .bodyMovement:
            return [
                "Optimal physical recovery",
                "Reduced muscle tension",
                "Better movement control"
            ]
        case .memoryProcessing:
            return [
                "Stronger memory formation",
                "Better learning outcomes",
                "Enhanced skill acquisition"
            ]
        case .energyRestoration:
            return [
                "Increased physical vitality",
                "Better immune function",
                "Improved tissue repair"
            ]
        }
    }
}

#Preview {
    StageComparisonDetailView(metric: .brainActivity)
}