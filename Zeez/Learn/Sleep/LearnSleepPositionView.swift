import SwiftUI
import CoreData

struct LearnSleepPositionView: View {
    @State private var selectedPosition: SleepPosition = .back

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Position detection is not implemented; all content below is educational.
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.orange)
                    Text("Educational content — position data shown is based on research, not measured from your device.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Notice: position data is educational and research-based, not measured from your device.")
                .accessibilityIdentifier("positionEducationalDisclaimerBanner")

                positionSelector

                qualitySection

                recommendationsSection
            }
            .padding()
        }
        .navigationTitle("Sleep Positions")
    }

    private var positionSelector: some View {
        Picker("Sleep Position", selection: $selectedPosition) {
            Text("Back").tag(SleepPosition.back)
            Text("Left Side").tag(SleepPosition.leftSide)
            Text("Right Side").tag(SleepPosition.rightSide)
            Text("Stomach").tag(SleepPosition.stomach)
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Select sleep position")
        .accessibilityHint("Choose a sleep position to view detailed information")
        .accessibilityIdentifier("sleepPositionPicker")
    }

    private var qualitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Research Overview")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            Text("Research generally associates the \(selectedPosition.rawValue) position with \(researchDescription(for: selectedPosition)). Position detection is not yet available in Zeez.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Research overview for \(selectedPosition.rawValue) position: \(researchDescription(for: selectedPosition)). Position detection is not yet available in Zeez.")
        .accessibilityIdentifier("qualitySection")
    }

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("General Recommendations")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            ForEach(generalRecommendations, id: \.self) { recommendation in
                Label(recommendation, systemImage: "checkmark.circle")
                    .font(.subheadline)
                    .accessibilityLabel("Recommendation: \(recommendation)")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("recommendationsSection")
    }

    private var generalRecommendations: [String] {
        ["Use supportive pillows for proper spinal alignment",
         "Keep your sleep environment cool, dark, and quiet",
         "Maintain a consistent sleep and wake schedule",
         "Consult a healthcare provider about specific positioning concerns"]
    }

    private func researchDescription(for position: SleepPosition) -> String {
        switch position {
        case .back:
            return "neutral spinal alignment but may worsen snoring or sleep apnea symptoms"
        case .leftSide:
            return "reduced acid reflux and improved circulation; generally recommended during pregnancy"
        case .rightSide:
            return "good spinal alignment; may increase acid reflux compared to left-side sleeping"
        case .stomach:
            return "increased strain on the neck and lower back; generally less recommended"
        case .unknown:
            return "variable outcomes depending on individual factors"
        }
    }
}

#Preview {
    NavigationView {
        LearnSleepPositionView()
    }
}
