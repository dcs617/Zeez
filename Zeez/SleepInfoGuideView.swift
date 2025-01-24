import SwiftUI

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
                        
                        ForEach(metrics, id: \.title) { metric in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: metric.icon)
                                    .foregroundStyle(.blue)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(metric.title)
                                        .font(.subheadline)
                                        .bold()
                                    
                                    Text(metric.description)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    
                    // Recommendations
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Sleep Recommendations")
                            .font(.headline)
                        
                        ForEach(recommendations, id: \.self) { tip in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .frame(width: 24)
                                
                                Text(tip)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
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
                }
            }
        }
    }
}

#Preview {
    SleepInfoGuideView()
}
