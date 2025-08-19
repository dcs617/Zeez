import SwiftUI
import os.log

struct TipSection: Identifiable {
    let id = UUID()
    let title: String
    let tips: [String]
}

struct SleepQualityTipsView: View {
    @Environment(\.dismiss) private var dismiss
    
    private let sleepTips: [TipSection] = [
        TipSection(
            title: "Sleep Schedule",
            tips: [
                "Go to bed and wake up at the same time every day",
                "Avoid sleeping in on weekends by more than an hour",
                "Create a consistent bedtime routine",
                "Aim for 7-9 hours of sleep each night"
            ]
        ),
        TipSection(
            title: "Environment",
            tips: [
                "Keep your bedroom temperature between 18-22°C (65-72°F)",
                "Maintain darkness with blackout curtains or an eye mask",
                "Use white noise or earplugs to block disruptive sounds",
                "Keep humidity levels between 30-50%"
            ]
        ),
        TipSection(
            title: "Daily Habits",
            tips: [
                "Avoid caffeine 6-8 hours before bedtime",
                "Exercise regularly, but not too close to bedtime",
                "Get natural sunlight exposure during the day",
                "Avoid large meals close to bedtime"
            ]
        ),
        TipSection(
            title: "Technology",
            tips: [
                "Avoid blue light exposure 1-2 hours before bed",
                "Keep electronic devices out of the bedroom",
                "Use night mode on essential devices",
                "Don't check the time if you wake up during the night"
            ]
        ),
        TipSection(
            title: "Relaxation",
            tips: [
                "Practice relaxation techniques before bed",
                "Try deep breathing exercises",
                "Consider meditation or gentle yoga",
                "Write down worries or to-do lists before bed"
            ]
        )
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(sleepTips) { section in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(section.title)
                                    .font(.headline)
                                    .accessibilityLabel("\(section.title) section")
                                
                                Spacer()
                                
                                Image(systemName: sectionIcon(for: section.title))
                                    .foregroundStyle(.blue)
                                    .accessibilityLabel("\(section.title) icon")
                            }
                            
                            ForEach(section.tips, id: \.self) { tip in
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "circle.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.blue)
                                        .padding(.top, 6)
                                        .accessibilityLabel("Tip bullet point")
                                    
                                    Text(tip)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("Tip: \(tip)")
                                .accessibilityIdentifier("tip_\(tip.prefix(20).replacingOccurrences(of: " ", with: "_"))")
                            }
                        }
                        .padding()
                        .background {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor.systemBackground))
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(section.title) tips: \(section.tips.joined(separator: ", "))")
                        .accessibilityIdentifier("tipSection_\(section.title.replacingOccurrences(of: " ", with: ""))")
                    }
                }
                .padding()
            }
            .navigationTitle("Sleep Quality Tips")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityLabel("Close sleep quality tips")
                    .accessibilityHint("Return to previous screen")
                    .accessibilityIdentifier("closeSleepQualityTipsButton")
                }
            }
            .background(Color(UIColor.secondarySystemBackground))
        }
    }
    
    private func sectionIcon(for title: String) -> String {
        switch title {
        case "Sleep Schedule": return "bed.double.fill"
        case "Environment": return "thermometer"
        case "Daily Habits": return "calendar"
        case "Technology": return "iphone"
        case "Relaxation": return "wind"
        default: return "star.fill"
        }
    }
}

#Preview {
    SleepQualityTipsView()
}
