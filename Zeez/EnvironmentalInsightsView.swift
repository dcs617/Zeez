import SwiftUI
import CoreData

/// Displays environmental analysis and recommendations
struct EnvironmentalInsightsView: View {
    let session: SleepSession
    
    @Environment(\.managedObjectContext) private var viewContext
    @State private var analysis: EnvironmentalAnalysis?
    @State private var isLoading = false
    @State private var error: Error?
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Analyzing environment...")
            } else if let analysis = analysis {
                ScrollView {
                    VStack(spacing: 20) {
                        qualityCorrelationSection(analysis.qualityCorrelation)
                        environmentalMetricsSection(analysis)
                        recommendationsSection(analysis.recommendations)
                    }
                    .padding()
                }
            } else if let error = error {
                Text("Analysis Error: \(error.localizedDescription)")
                    .foregroundColor(.red)
            } else {
                Text("No environmental data available")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Environmental Analysis")
        .task {
            await analyzeEnvironment()
        }
    }
    
    private func qualityCorrelationSection(_ correlation: QualityCorrelation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quality Impact")
                .font(.headline)
            
            VStack(spacing: 16) {
                correlationRow(
                    label: "Temperature",
                    impact: correlation.temperatureImpact,
                    icon: "thermometer"
                )
                
                correlationRow(
                    label: "Humidity",
                    impact: correlation.humidityImpact,
                    icon: "humidity"
                )
                
                correlationRow(
                    label: "Noise",
                    impact: correlation.noiseImpact,
                    icon: "ear"
                )
                
                correlationRow(
                    label: "Light",
                    impact: correlation.lightImpact,
                    icon: "lightbulb"
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private func correlationRow(label: String, impact: Double, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
            
            Text(label)
            
            Spacer()
            
            impactIndicator(score: impact)
        }
    }
    
    private func impactIndicator(score: Double) -> some View {
        HStack(spacing: 4) {
            Text(String(format: "%.0f%%", score * 100))
                .foregroundColor(impactColor(score))
            
            Image(systemName: impactIcon(score))
                .foregroundColor(impactColor(score))
        }
    }
    
    private func environmentalMetricsSection(_ analysis: EnvironmentalAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Measurements")
                .font(.headline)
            
            VStack(spacing: 16) {
                metricRow(
                    label: "Temperature",
                    metrics: analysis.temperature,
                    unit: "°C"
                )
                
                metricRow(
                    label: "Humidity",
                    metrics: analysis.humidity,
                    unit: "%"
                )
                
                metricRow(
                    label: "Noise",
                    metrics: analysis.noise,
                    unit: "dB"
                )
                
                metricRow(
                    label: "Light",
                    metrics: analysis.light,
                    unit: "lux"
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private func metricRow(
        label: String,
        metrics: EnvironmentalStatistics,
        unit: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .fontWeight(.medium)
            
            HStack {
                metricValue("Avg", value: metrics.average, unit: unit)
                Spacer()
                metricValue("Min", value: metrics.minimum, unit: unit)
                Spacer()
                metricValue("Max", value: metrics.maximum, unit: unit)
            }
            
            varianceIndicator(metrics.variance)
        }
    }
    
    private func metricValue(_ label: String, value: Double, unit: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("\(String(format: "%.1f", value))\(unit)")
                .font(.subheadline)
        }
    }
    
    private func varianceIndicator(_ variance: Double) -> some View {
        HStack {
            Text("Stability:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(stabilityDescription(variance))
                .font(.caption)
                .foregroundColor(stabilityColor(variance))
        }
    }
    
    private func recommendationsSection(_ recommendations: [EnvironmentalRecommendation]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommendations")
                .font(.headline)
            
            if recommendations.isEmpty {
                Text("Environmental conditions are optimal")
                    .font(.subheadline)
                    .foregroundColor(.green)
            } else {
                ForEach(recommendations, id: \.description) { recommendation in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "arrow.up.forward")
                            .foregroundColor(.blue)
                        
                        Text(recommendation.description)
                            .font(.subheadline)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private func analyzeEnvironment() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let analyzer = EnvironmentalAnalyzer(context: viewContext)
            analysis = try await analyzer.analyzeSession(session)
        } catch {
            self.error = error
        }
    }
    
    // MARK: - Helper Methods
    
    private func impactColor(_ score: Double) -> Color {
        switch score {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .blue
        case 0.4..<0.6: return .yellow
        default: return .red
        }
    }
    
    private func impactIcon(_ score: Double) -> String {
        switch score {
        case 0.8...1.0: return "checkmark.circle.fill"
        case 0.6..<0.8: return "arrow.up.circle.fill"
        case 0.4..<0.6: return "exclamationmark.circle.fill"
        default: return "xmark.circle.fill"
        }
    }
    
    private func stabilityDescription(_ variance: Double) -> String {
        switch variance {
        case 0...5: return "Very Stable"
        case 5...10: return "Stable"
        case 10...20: return "Variable"
        default: return "Unstable"
        }
    }
    
    private func stabilityColor(_ variance: Double) -> Color {
        switch variance {
        case 0...5: return .green
        case 5...10: return .blue
        case 10...20: return .yellow
        default: return .red
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let session = SleepSession(context: context)
    
    return NavigationView {
        EnvironmentalInsightsView(session: session)
            .environment(\.managedObjectContext, context)
    }
}
