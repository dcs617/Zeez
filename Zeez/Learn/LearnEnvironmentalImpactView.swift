import SwiftUI

struct LearnEnvironmentalImpactView: View {
    @State private var selectedFactor: EnvironmentalFactor = .temperature

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.orange)
                Text("Educational content only. Zeez is not currently measuring or evaluating your sleep environment.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Educational content only. Zeez is not currently measuring or evaluating your sleep environment.")

            factorSelector

            educationalOverview
        }
        .padding()
    }

    private var factorSelector: some View {
        Picker("Environmental Factor", selection: $selectedFactor) {
            ForEach(EnvironmentalFactor.allCases, id: \.self) { factor in
                HStack {
                    Image(systemName: factor.icon)
                    Text(factor.rawValue)
                }.tag(factor)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Select environmental factor")
        .accessibilityHint("Choose an environmental factor to read about")
        .accessibilityIdentifier("environmentalFactorPicker")
    }

    private var educationalOverview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(selectedFactor.rawValue)
                .font(.headline)
            Text(educationalText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(selectedFactor.rawValue): \(educationalText)")
    }

    private var educationalText: String {
        switch selectedFactor {
        case .temperature:
            return "Room temperature can affect comfort during sleep. This is general information, not a reading from your room."
        case .light:
            return "Light exposure can affect sleep routines. This is general information, not a measurement from your room."
        case .sound:
            return "Noise can disrupt sleep for some people. This is general information, not a measurement from your room."
        }
    }
}

#Preview {
    LearnEnvironmentalImpactView()
        .padding()
}
