import SwiftUI
import CoreData

/// Settings view for managing sleep analysis personalization
struct PersonalizationSettingsView: View {
    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Sleep personalization is not yet available. Analysis and measurements shown in this view will reflect your data in a future update.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Personalization not yet available. Data shown will reflect your sleep in a future update.")
                    .accessibilityIdentifier("personalizationUnavailableBanner")
                }

                Section {
                    Label("Sleep Patterns", systemImage: "waveform")
                    Label("Quality Trends", systemImage: "chart.line.uptrend.xyaxis")
                    Label("Bedtime Consistency", systemImage: "clock.fill")
                } header: {
                    Text("Coming Soon")
                } footer: {
                    Text("Personalization features are coming in a future update. They will use your recorded sleep data to provide tailored insights.")
                }
            }
            .navigationTitle("Sleep Personalization")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
