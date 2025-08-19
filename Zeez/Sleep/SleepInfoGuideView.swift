import SwiftUI
import os.log

struct SleepInfoGuideView: View {
    @Environment(\.dismiss) private var dismiss
    
    private let metrics = [
        (title: "Sleep Efficiency", icon: "chart.pie.fill", description: "The percentage of time in bed that you spend actually sleeping. A score above 85% is considered good."),
        (title: "Sleep Debt", icon: "hourglass", description: "The cumulative effect of not getting enough sleep. It's calculated based on the difference between your actual sleep and target sleep duration."),
        (title: "Sleep Consistency", icon: "clock.fill", description: "How regular your sleep schedule is. Going to bed and waking up at consistent times improves sleep quality."),
        (title: "Environmental Factors", icon: "thermometer", description: "Optimal sleep conditions: Temperature (18-22°C), Humidity (30-50%), minimal light and noise levels.")
    ]
    
    private let recommendations = [
        "Maintain a consistent sleep schedule",
        "Aim for 7-9 hours of sleep per night",
        "Keep your bedroom cool, dark, and quiet",
        "Avoid screens 1-2 hours before bed",
        "Exercise regularly, but not too close to bedtime",
        "Limit caffeine and alcohol consumption",
        "Create a relaxing bedtime routine"
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Metrics Explanation
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Understanding Your Metrics")
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("metricsHeader")
                        
                        ForEach(Array(metrics.enumerated()), id: \.element.title) { index, metric in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: metric.icon)
                                    .foregroundStyle(.blue)
                                    .frame(width: 24)
                                    .accessibilityHidden(true)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(metric.title)
                                        .font(.subheadline)
                                        .bold()
                                    
                                    Text(metric.description)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(metric.title): \(metric.description)")
                            .accessibilityIdentifier("metric_\(index)")
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("metricsSection")
                    
                    // Recommendations
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Sleep Recommendations")
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("recommendationsHeader")
                        
                        ForEach(Array(recommendations.enumerated()), id: \.element) { index, tip in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .frame(width: 24)
                                    .accessibilityHidden(true)
                                
                                Text(tip)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Recommendation \(index + 1): \(tip)")
                            .accessibilityIdentifier("recommendation_\(index)")
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("recommendationsSection")
                }
                .padding()
            }
            .navigationTitle("Sleep Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityLabel("Close sleep guide")
                    .accessibilityHint("Return to previous screen")
                    .accessibilityIdentifier("doneButton")
                }
            }
        }
        .accessibilityIdentifier("sleepInfoGuideView")
    }
}

#Preview {
    SleepInfoGuideView()
}
