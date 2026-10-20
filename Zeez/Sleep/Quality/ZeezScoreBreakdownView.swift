import SwiftUI

/// Shows how an Experimental Zeez Estimate was assembled: each component, its weight, and
/// its score or why it was unavailable. See `ZeezScoreBreakdown` for when it is shown.
struct ZeezScoreBreakdownView: View {
    let session: SleepSession

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How This Estimate Was Calculated")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            switch ZeezScoreBreakdown.make(for: session) {
            case .available(let breakdown):
                content(for: breakdown)
            case .unavailable(let reason):
                Text(reason.displayText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("scoreBreakdownUnavailable")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(UIColor.secondarySystemBackground))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("scoreBreakdown")
    }

    @ViewBuilder
    private func content(for breakdown: ZeezScoreBreakdown) -> some View {
        Text("The experimental Zeez estimate is a weighted combination of these inputs, each scored out of 100.")
            .font(.caption)
            .foregroundColor(.secondary)

        VStack(spacing: 12) {
            ForEach(breakdown.entries) { entry in
                row(for: entry)
                if entry.id != breakdown.entries.last?.id {
                    Divider()
                }
            }
        }

        if breakdown.hasUnavailableComponents {
            Text("Unavailable inputs are left out, and the remaining weights are scaled up to fill their share. They are never counted as average. Inputs available: \(Int(breakdown.inputCoverage.rounded()))% of the estimate's weight.")
                .font(.caption)
                .foregroundColor(.secondary)
                .accessibilityIdentifier("scoreBreakdownCoverageNote")
        }
    }

    private func row(for entry: ZeezScoreBreakdown.Entry) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.component.displayName)
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Text(entry.component.explanation)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("\(entry.component.weightPercent)% of the estimate")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 8)

            switch entry.result {
            case .available(let score):
                Text("\(Int(score.rounded()))")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            case .unavailable:
                Text("Not available")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.trailing)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entry.component.displayName), \(entry.component.weightPercent) percent of the estimate")
        .accessibilityValue(Self.accessibilityValue(for: entry.result))
        .accessibilityHint(entry.component.explanation)
        .accessibilityIdentifier("scoreBreakdownRow.\(entry.component.rawValue)")
    }

    /// Carries the experimental label so a component score never reaches VoiceOver as a
    /// bare personal result (claims rule 10).
    static func accessibilityValue(for result: ComponentResult) -> String {
        switch result {
        case .available(let score):
            return "Experimental Zeez estimate component: \(Int(score.rounded())) out of 100"
        case .unavailable(let reason):
            return "Not available: \(reason.displayText)"
        }
    }
}
