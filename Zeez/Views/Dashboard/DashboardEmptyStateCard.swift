import SwiftUI

/// Shown on the dashboard when the store holds no completed sleep sessions.
///
/// Before this existed, a first run rendered a grid of empty metric cards with no route to
/// the one action that produces data (second-audit B11). The card replaces those cards
/// rather than sitting above them, so the first screen has a single obvious next step.
struct DashboardEmptyStateCard: View {
    let onImport: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.arrow.down.on.square")
                .font(.system(size: 44))
                .foregroundStyle(.blue)
                .accessibilityHidden(true)

            Text("No Sleep Data Yet")
                .font(.headline)

            Text("Import your sleep history from Apple Health to see your recorded sessions, stages, and trends.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(action: onImport) {
                Text("Import from Apple Health")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .accessibilityLabel("Import from Apple Health")
            .accessibilityHint("Opens the importer to bring your sleep history into Zeez")
            .accessibilityIdentifier("dashboardImportButton")

            Text("You can also record a session from the Sleep tab.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground))
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("No sleep data yet")
        .accessibilityIdentifier("dashboardEmptyState")
    }
}

#Preview {
    DashboardEmptyStateCard(onImport: {})
        .padding()
}
