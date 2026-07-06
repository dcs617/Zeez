import SwiftUI
import CoreData

struct LearnSleepDebtView: View {
    @Environment(\.managedObjectContext) private var viewContext

    private var summary: SleepGoalShortfallSummary? {
        SleepDebtCalculator.shared.summary(context: viewContext)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                trackingContent
                educationalContent
            }
            .padding()
        }
        .navigationTitle("Sleep Goal Shortfall")
    }

    @ViewBuilder
    private var trackingContent: some View {
        if let summary, summary.coveredDayCount > 0 {
            VStack(alignment: .leading, spacing: 16) {
                Text("Sleep Goal Shortfall")
                    .font(.headline)

                HStack(alignment: .firstTextBaseline) {
                    Text(formatDuration(summary.totalShortfall))
                        .font(.title2.weight(.semibold))
                    Spacer()
                    Text("\(summary.coveredDayCount) of \(summary.periodDays) days recorded")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    summaryRow(title: "Your goal", value: formatDuration(summary.goalDuration))
                    Spacer()
                    summaryRow(title: "Average recorded", value: formatDuration(summary.averageComparedDuration))
                }

                Text(summary.usesEstimatedDurations
                     ? "Calculated against your selected goal using Apple Health-reported sleep where available and recorded Zeez session duration otherwise. Days without usable data are excluded."
                     : "Calculated against your selected goal using Apple Health-reported sleep. Days without usable data are excluded.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("This is a tracking comparison, not an estimate of medical sleep need or recovery time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Sleep goal shortfall \(formatDuration(summary.totalShortfall)) based on \(summary.coveredDayCount) recorded days in the last \(summary.periodDays) days")
            .accessibilityIdentifier("sleepGoalShortfallSummary")
        } else {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.orange)
                Text("Enable a sleep goal and record sleep sessions to calculate a seven-day goal shortfall. The content below is educational.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Sleep goal shortfall requires an enabled goal and recorded sleep data. Content below is educational.")
            .accessibilityIdentifier("sleepDebtDataUnavailableBanner")
        }
    }

    private func summaryRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.medium))
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration.rounded()) / 60
        return "\(minutes / 60)h \(minutes % 60)m"
    }

    private var educationalContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            educationCard(
                icon: "moon.zzz.fill",
                title: "What Is Sleep Debt?",
                body: "Sleep debt accumulates when you consistently sleep less than your body needs. Research shows that most adults require 7–9 hours per night. Falling short even by one hour nightly can add up over a week."
            )

            educationCard(
                icon: "chart.line.downtrend.xyaxis",
                title: "Effects of Sleep Debt",
                body: "Accumulated sleep debt is associated with reduced cognitive performance, slower reaction time, impaired memory consolidation, and increased risk of mood disturbances. Chronic sleep debt may have longer-term health consequences."
            )

            educationCard(
                icon: "arrow.triangle.2.circlepath",
                title: "Recovery",
                body: "Recovery from short-term sleep debt is possible with consistent, adequate sleep. Longer-term sleep debt may take more time to resolve. Weekend \"catch-up\" sleep partially offsets the effects but does not fully reverse all impacts."
            )

            educationCard(
                icon: "bed.double.fill",
                title: "Improving Sleep",
                body: "Consistent sleep and wake times, a cool and dark environment, limiting screen exposure before bed, and avoiding caffeine in the afternoon are among the most evidence-supported strategies for better sleep."
            )
        }
    }

    private func educationCard(icon: String, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.headline)
            }
            Text(body)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(body)")
    }
}

#Preview {
    LearnSleepDebtView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
