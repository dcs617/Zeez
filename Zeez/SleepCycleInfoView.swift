import SwiftUI

struct SleepCycleInfoView: View {
    @Environment(\.dismiss) private var dismiss
    
    private let stages = [
        (name: "Light Sleep", description: "Initial stage where you can be easily awakened. Your muscles begin to relax and your heart rate slows.", icon: "cloud.fill", color: Color.blue),
        (name: "Deep Sleep", description: "The most restorative stage. Your body repairs tissues, builds bone and muscle, and strengthens the immune system.", icon: "moon.fill", color: Color.indigo),
        (name: "REM Sleep", description: "Where most dreaming occurs. Important for memory consolidation and emotional processing.", icon: "sparkles", color: Color.purple),
        (name: "Sleep Cycle", description: "A complete cycle lasts about 90 minutes, with 4-6 cycles per night being ideal.", icon: "repeat", color: Color.green)
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Introduction
                    introSection
                    
                    // Sleep Stages
                    stagesSection
                    
                    // Tips
                    tipsSection
                }
                .padding()
            }
            .navigationTitle("Understanding Sleep Cycles")
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
    
    private var introSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What are Sleep Cycles?")
                .font(.headline)
            
            Text("During sleep, your body goes through multiple cycles of different sleep stages. Each cycle typically lasts around 90 minutes, and a good night's sleep consists of 4-6 complete cycles.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var stagesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sleep Stages")
                .font(.headline)
            
            ForEach(stages, id: \.name) { stage in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: stage.icon)
                            .foregroundStyle(stage.color)
                        
                        Text(stage.name)
                            .font(.subheadline)
                            .bold()
                    }
                    
                    Text(stage.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.secondarySystemBackground))
                }
            }
        }
    }
    
    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tips for Better Sleep Cycles")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                tipRow(
                    icon: "bed.double.fill",
                    title: "Consistent Schedule",
                    description: "Go to bed and wake up at the same time daily to maintain regular cycles"
                )
                
                tipRow(
                    icon: "clock.fill",
                    title: "Time Your Sleep",
                    description: "Plan your sleep in 90-minute increments to complete full cycles"
                )
                
                tipRow(
                    icon: "moon.stars.fill",
                    title: "Create the Right Environment",
                    description: "Dark, quiet, and cool conditions support better sleep cycles"
                )
                
                tipRow(
                    icon: "sparkles",
                    title: "Avoid Disruptions",
                    description: "Minimize interruptions that can break your sleep cycles"
                )
            }
        }
    }
    
    private func tipRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .bold()
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    SleepCycleInfoView()
}
