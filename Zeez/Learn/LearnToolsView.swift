import SwiftUI
import os.log

struct LearnToolsView: View {
    @State private var isLoading = true
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                NavigationLink(destination: LearnBrainActivityVisualizer()) {
                    ToolGridCard(
                        title: "Brain Activity",
                        icon: "brain.head.profile",
                        color: .blue,
                        description: "Explore brain wave patterns during sleep",
                        delay: 0.0
                    )
                }
                .accessibilityLabel("Brain Activity tool")
                .accessibilityHint("Learn about brain wave patterns during sleep")
                .accessibilityIdentifier("brainActivityTool")
                
                NavigationLink(destination: LearnCircadianRhythmView()) {
                    ToolGridCard(
                        title: "Circadian Rhythm",
                        icon: "clock",
                        color: .orange,
                        description: "Understand your natural sleep cycle",
                        delay: 0.1
                    )
                }
                .accessibilityLabel("Circadian Rhythm tool")
                .accessibilityHint("Learn about your natural sleep cycle")
                .accessibilityIdentifier("circadianRhythmTool")
                
                NavigationLink(destination: LearnEnvironmentalImpactView()) {
                    ToolGridCard(
                        title: "Environmental",
                        icon: "thermometer.sun",
                        color: .green,
                        description: "Impact of environment on sleep",
                        delay: 0.2
                    )
                }
                .accessibilityLabel("Environmental impact tool")
                .accessibilityHint("Learn about environmental impacts on sleep")
                .accessibilityIdentifier("environmentalTool")
                
                NavigationLink(destination: LearnSleepPositionView()) {
                    ToolGridCard(
                        title: "Sleep Positions",
                        icon: "bed.double",
                        color: .purple,
                        description: "Best positions for quality sleep",
                        delay: 0.3
                    )
                }
                .accessibilityLabel("Sleep positions tool")
                .accessibilityHint("Learn about best sleep positions for quality rest")
                .accessibilityIdentifier("sleepPositionsTool")
                
                NavigationLink(destination: LearnSleepDebtView()) {
                    ToolGridCard(
                        title: "Sleep Debt",
                        icon: "chart.pie",
                        color: .red,
                        description: "Calculate and recover sleep debt",
                        delay: 0.4
                    )
                }
                .accessibilityLabel("Sleep debt tool")
                .accessibilityHint("Learn how to calculate and recover from sleep debt")
                .accessibilityIdentifier("sleepDebtTool")
                
                NavigationLink(destination: LearnSleepStageComparisonView()) {
                    ToolGridCard(
                        title: "Sleep Stages",
                        icon: "waveform.path",
                        color: .indigo,
                        description: "Compare REM and Deep Sleep",
                        delay: 0.5
                    )
                }
                .accessibilityLabel("Sleep stages tool")
                .accessibilityHint("Compare REM and deep sleep stages")
                .accessibilityIdentifier("sleepStagesTool")
            }
            .padding()
        }
        .navigationTitle("Sleep Tools")
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                isLoading = false
            }
        }
        .onDisappear {
            isLoading = true
        }
    }
}

struct ToolGridCard: View {
    let title: String
    let icon: String
    let color: Color
    let description: String
    let delay: Double
    
    @State private var isHovered = false
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .scaleEffect(isHovered ? 1.1 : 1.0)
                .accessibilityHidden(true)
            
            Text(title)
                .font(.headline)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .scaleEffect(isAnimating ? 1 : 0.9)
        .opacity(isAnimating ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(delay)) {
                isAnimating = true
            }
        }
        .onDisappear {
            isAnimating = false
        }
        .onHover { hovering in
            withAnimation(.spring()) {
                isHovered = hovering
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(description)")
        .accessibilityIdentifier("toolGridCard_\(title.lowercased().replacingOccurrences(of: " ", with: ""))")
    }
}

#Preview {
    NavigationView {
        LearnToolsView()
    }
}
