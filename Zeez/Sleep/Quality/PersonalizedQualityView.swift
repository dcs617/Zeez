import SwiftUI
import CoreData

/// Enhanced sleep quality view that displays personalization information and confidence scores
struct PersonalizedQualityView: View {
    let session: SleepSession
    @Environment(\.managedObjectContext) private var viewContext
    @State private var enhancedAnalysis: SleepQualityAnalysisResult?
    @State private var isLoading = false
    
    private var qualityScore: SleepQualityScore? {
        session.qualityScores?.allObjects.first as? SleepQualityScore
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                overallScoreSection
                
                if let analysis = enhancedAnalysis {
                    personalizationInfoSection(analysis)
                    detailedMetricsSection(analysis)
                    confidenceSection(analysis)
                }
                
                if isLoading {
                    ProgressView("Analyzing personalization...")
                        .frame(maxWidth: .infinity, minHeight: 100)
                }
            }
            .padding()
        }
        .navigationTitle("Personalized Sleep Quality")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadEnhancedAnalysis()
        }
    }
    
    private var overallScoreSection: some View {
        VStack(spacing: 16) {
            QualityScoreRing(
                score: session.qualityScore,
                size: 140,
                lineWidth: 10
            )
            
            VStack(spacing: 4) {
                Text("Your Sleep Quality")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                if let score = qualityScore, score.isPersonalized {
                    Label("Personalized Analysis", systemImage: "person.fill")
                        .font(.caption)
                        .foregroundStyle(.purple)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(UIColor.secondarySystemBackground))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sleep quality score: \(Int(session.qualityScore))%. \(qualityScore?.isPersonalized == true ? "Using personalized analysis" : "Using standard analysis")")
    }
    
    @ViewBuilder
    private func personalizationInfoSection(_ analysis: SleepQualityAnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Personalization Status")
                .font(.headline)
            
            HStack {
                Image(systemName: personalizationIcon(analysis.personalizationLevel))
                    .foregroundStyle(personalizationColor(analysis.personalizationLevel))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(personalizationTitle(analysis.personalizationLevel))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(personalizationDescription(analysis.personalizationLevel))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text("\(Int(analysis.confidence))%")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(confidenceColor(analysis.confidence))
            }
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(personalizationColor(analysis.personalizationLevel).opacity(0.1))
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(UIColor.secondarySystemBackground))
        }
    }
    
    @ViewBuilder
    private func detailedMetricsSection(_ analysis: SleepQualityAnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quality Components")
                .font(.headline)
            
            VStack(spacing: 12) {
                QualityMetricRow(
                    title: "Heart Rate",
                    score: analysis.heartRateScore,
                    icon: "heart.fill",
                    isPersonalized: isComponentPersonalized("heartRate")
                )
                
                QualityMetricRow(
                    title: "Movement",
                    score: analysis.movementScore,
                    icon: "figure.walk",
                    isPersonalized: isComponentPersonalized("movement")
                )
                
                QualityMetricRow(
                    title: "Environment",
                    score: analysis.environmentalScore,
                    icon: "thermometer",
                    isPersonalized: isComponentPersonalized("environmental")
                )
                
                QualityMetricRow(
                    title: "Respiratory",
                    score: analysis.respiratoryScore,
                    icon: "lungs.fill",
                    isPersonalized: false
                )
                
                QualityMetricRow(
                    title: "Sleep Cycles",
                    score: analysis.sleepCycleScore,
                    icon: "waveform.path.ecg",
                    isPersonalized: false
                )
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(UIColor.secondarySystemBackground))
        }
    }
    
    @ViewBuilder
    private func confidenceSection(_ analysis: SleepQualityAnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Analysis Confidence")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: analysis.confidence / 100) {
                    HStack {
                        Text("Overall Confidence")
                            .font(.subheadline)
                        Spacer()
                        Text("\(Int(analysis.confidence))%")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
                .progressViewStyle(LinearProgressViewStyle(tint: confidenceColor(analysis.confidence)))
                
                Text(confidenceExplanation(analysis.confidence))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(UIColor.secondarySystemBackground))
        }
    }
    
    // MARK: - Helper Functions
    
    private func loadEnhancedAnalysis() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let analyzer = SleepQualityAnalyzer(context: viewContext, session: session)
            enhancedAnalysis = try await analyzer.getEnhancedAnalysisResult()
        } catch {
            // Handle error - could show an alert or fallback UI
            print("Failed to load enhanced analysis: \(error)")
        }
    }
    
    private func isComponentPersonalized(_ component: String) -> Bool {
        guard let score = qualityScore,
              let componentsJson = score.personalizedComponents,
              let data = componentsJson.data(using: .utf8),
              let components = try? JSONSerialization.jsonObject(with: data) as? [String: Bool] else {
            return false
        }
        return components[component] ?? false
    }
    
    private func personalizationIcon(_ level: SleepQualityAnalysisResult.PersonalizationLevel) -> String {
        switch level {
        case .none: return "person"
        case .basic: return "person.badge.plus"
        case .advanced: return "person.fill.badge.plus"
        case .expert: return "brain"
        }
    }
    
    private func personalizationColor(_ level: SleepQualityAnalysisResult.PersonalizationLevel) -> Color {
        switch level {
        case .none: return .gray
        case .basic: return .blue
        case .advanced: return .purple
        case .expert: return .indigo
        }
    }
    
    private func personalizationTitle(_ level: SleepQualityAnalysisResult.PersonalizationLevel) -> String {
        switch level {
        case .none: return "Standard Analysis"
        case .basic: return "Basic Personalization"
        case .advanced: return "Advanced Personalization"
        case .expert: return "Expert Personalization"
        }
    }
    
    private func personalizationDescription(_ level: SleepQualityAnalysisResult.PersonalizationLevel) -> String {
        switch level {
        case .none: return "Using population-based averages"
        case .basic: return "Some components use your personal patterns"
        case .advanced: return "Most components tailored to your patterns"
        case .expert: return "Fully personalized analysis using extensive history"
        }
    }
    
    private func confidenceColor(_ confidence: Double) -> Color {
        switch confidence {
        case 80...: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }
    
    private func confidenceExplanation(_ confidence: Double) -> String {
        switch confidence {
        case 80...: return "High confidence - analysis is very reliable"
        case 60..<80: return "Good confidence - analysis is reliable with some uncertainty"
        case 40..<60: return "Moderate confidence - analysis may have some limitations"
        default: return "Lower confidence - analysis based on limited data"
        }
    }
}

// MARK: - Supporting Views

private struct QualityMetricRow: View {
    let title: String
    let score: Double
    let icon: String
    let isPersonalized: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
            
            if isPersonalized {
                Image(systemName: "person.fill")
                    .foregroundStyle(.purple)
                    .font(.caption)
            }
            
            Spacer()
            
            Text("\(Int(score))%")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(scoreColor(score))
        }
        .padding(.vertical, 4)
    }
    
    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 80...: return .green
        case 60..<80: return .orange
        default: return .red
        }
    }
}

