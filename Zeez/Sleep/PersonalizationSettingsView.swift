import SwiftUI
import CoreData

/// Settings view for managing sleep analysis personalization
struct PersonalizationSettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var personalizedBaselines: PersonalizedBaselines?
    @State private var sleepPatterns: SleepPatternAnalysis?
    @State private var isLoading = false
    @State private var showingResetAlert = false
    
    private let personalizationManager = PersonalizationManager.shared
    private let historicalAnalyzer = HistoricalAnalyzer()
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    dataMaturitySection
                } header: {
                    Text("Personalization Status")
                }
                
                if let baselines = personalizedBaselines {
                    Section {
                        personalizedRangesSection(baselines)
                    } header: {
                        Text("Your Sleep Patterns")
                    }
                }
                
                if let patterns = sleepPatterns {
                    Section {
                        sleepInsightsSection(patterns)
                    } header: {
                        Text("Sleep Insights")
                    }
                }
                
                Section {
                    dataManagementSection
                } header: {
                    Text("Data Management")
                } footer: {
                    Text("Resetting personalization data will make the app use standard analysis until new patterns are established.")
                }
            }
            .navigationTitle("Sleep Personalization")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadPersonalizationData()
            }
            .alert("Reset Personalization Data", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    resetPersonalizationData()
                }
            } message: {
                Text("This will reset all your personalized sleep analysis patterns. The app will start learning your patterns again from new sleep data.")
            }
        }
    }
    
    @ViewBuilder
    private var dataMaturitySection: some View {
        if let baselines = personalizedBaselines {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: dataMaturityIcon(baselines))
                        .foregroundStyle(dataMaturityColor(baselines))
                    
                    Text(dataMaturityTitle(baselines))
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(baselines.sessionCount) sessions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Text(dataMaturityDescription(baselines))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                ProgressView(value: Double(min(baselines.sessionCount, 60)) / 60.0) {
                    Text("Data Collection Progress")
                        .font(.caption)
                }
                .progressViewStyle(LinearProgressViewStyle(tint: dataMaturityColor(baselines)))
            }
            .padding(.vertical, 4)
        } else if isLoading {
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Loading personalization status...")
                    .foregroundStyle(.secondary)
            }
        } else {
            Text("No personalization data available")
                .foregroundStyle(.secondary)
        }
    }
    
    @ViewBuilder
    private func personalizedRangesSection(_ baselines: PersonalizedBaselines) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Average Sleep Duration", systemImage: "clock.fill")
                Spacer()
                Text("\(baselines.averageSleepDuration / 3600, specifier: "%.1f") hours")
                    .fontWeight(.medium)
            }
            
            HStack {
                Label("Bedtime Consistency", systemImage: "bed.double.fill")
                Spacer()
                Text("\(baselines.bedtimeConsistency, specifier: "%.0f")%")
                    .fontWeight(.medium)
                    .foregroundStyle(consistencyColor(baselines.bedtimeConsistency))
            }
            
            HStack {
                Label("Wake Time Consistency", systemImage: "sunrise.fill")
                Spacer()
                Text("\(baselines.wakeTimeConsistency, specifier: "%.0f")%")
                    .fontWeight(.medium)
                    .foregroundStyle(consistencyColor(baselines.wakeTimeConsistency))
            }
            
            HStack {
                Label("Duration Variability", systemImage: "chart.line.uptrend.xyaxis")
                Spacer()
                Text("± \(baselines.sleepDurationVariability / 3600, specifier: "%.1f") hours")
                    .fontWeight(.medium)
                    .foregroundStyle(variabilityColor(baselines.sleepDurationVariability))
            }
        }
    }
    
    @ViewBuilder
    private func sleepInsightsSection(_ patterns: SleepPatternAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Analysis Confidence", systemImage: "checkmark.seal.fill")
                Spacer()
                Text("\(patterns.confidence, specifier: "%.0f")%")
                    .fontWeight(.medium)
                    .foregroundStyle(confidenceColor(patterns.confidence))
            }
            
            HStack {
                Label("Quality Trend", systemImage: "chart.line.uptrend.xyaxis")
                Spacer()
                Text(trendDescription(patterns.qualityTrends.trend))
                    .fontWeight(.medium)
                    .foregroundStyle(trendColor(patterns.qualityTrends.trend))
            }
            
            HStack {
                Label("Average Quality", systemImage: "star.fill")
                Spacer()
                Text("\(patterns.qualityTrends.averageScore, specifier: "%.0f")%")
                    .fontWeight(.medium)
                    .foregroundStyle(scoreColor(patterns.qualityTrends.averageScore))
            }
        }
    }
    
    @ViewBuilder
    private var dataManagementSection: some View {
        Button("Reset Personalization Data") {
            showingResetAlert = true
        }
        .foregroundStyle(.red)
        
        Button("Export Sleep Data") {
            exportSleepData()
        }
        
        NavigationLink("View Detailed Analytics") {
            HistoricalAnalyticsView()
        }
    }
    
    // MARK: - Actions
    
    private func loadPersonalizationData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            async let baselines = personalizationManager.calculatePersonalizedBaselines()
            async let patterns = historicalAnalyzer.analyzeSleepPatterns(days: 30)
            
            personalizedBaselines = try await baselines
            sleepPatterns = try await patterns
        } catch {
            print("Failed to load personalization data: \(error)")
        }
    }
    
    private func resetPersonalizationData() {
        // In a real implementation, this would clear stored patterns and preferences
        // For now, we'll just reload the data
        Task {
            await loadPersonalizationData()
        }
    }
    
    private func exportSleepData() {
        // Implementation would export user's sleep data
        // This is a placeholder for the actual export functionality
        print("Export sleep data functionality would be implemented here")
    }
    
    // MARK: - Helper Functions
    
    private func dataMaturityIcon(_ baselines: PersonalizedBaselines) -> String {
        switch baselines.sessionCount {
        case 0..<7: return "person"
        case 7..<21: return "person.badge.plus"
        case 21..<60: return "person.fill.badge.plus"
        default: return "brain"
        }
    }
    
    private func dataMaturityColor(_ baselines: PersonalizedBaselines) -> Color {
        switch baselines.sessionCount {
        case 0..<7: return .gray
        case 7..<21: return .blue
        case 21..<60: return .purple
        default: return .indigo
        }
    }
    
    private func dataMaturityTitle(_ baselines: PersonalizedBaselines) -> String {
        switch baselines.sessionCount {
        case 0..<7: return "Building Your Profile"
        case 7..<21: return "Basic Personalization"
        case 21..<60: return "Advanced Personalization"
        default: return "Expert Personalization"
        }
    }
    
    private func dataMaturityDescription(_ baselines: PersonalizedBaselines) -> String {
        switch baselines.sessionCount {
        case 0..<7: return "We're learning your sleep patterns. More data will improve analysis accuracy."
        case 7..<21: return "Basic personalization active. Sleep analysis is becoming more tailored to you."
        case 21..<60: return "Advanced personalization active. Analysis is well-adapted to your patterns."
        default: return "Expert-level personalization. Analysis is fully tailored to your unique sleep patterns."
        }
    }
    
    private func consistencyColor(_ consistency: Double) -> Color {
        switch consistency {
        case 80...: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }
    
    private func variabilityColor(_ variability: TimeInterval) -> Color {
        let hours = variability / 3600
        switch hours {
        case 0..<1: return .green
        case 1..<2: return .orange
        default: return .red
        }
    }
    
    private func confidenceColor(_ confidence: Double) -> Color {
        switch confidence {
        case 80...: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }
    
    private func trendDescription(_ trend: TrendDirection) -> String {
        switch trend {
        case .improving: return "Improving"
        case .declining: return "Declining"
        case .stable: return "Stable"
        }
    }
    
    private func trendColor(_ trend: TrendDirection) -> Color {
        switch trend {
        case .improving: return .green
        case .declining: return .red
        case .stable: return .blue
        }
    }
    
    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 80...: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }
}

// MARK: - Supporting View

private struct HistoricalAnalyticsView: View {
    var body: some View {
        VStack {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            
            Text("Detailed Analytics")
                .font(.title2)
                .fontWeight(.medium)
                .padding(.top)
            
            Text("This view would show comprehensive historical sleep analysis, trends, and insights.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .navigationTitle("Sleep Analytics")
        .navigationBarTitleDisplayMode(.inline)
    }
}