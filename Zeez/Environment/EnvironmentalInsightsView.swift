import SwiftUI
import CoreData
import os.log

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
                    .accessibilityLabel("Analyzing environmental data")
                    .accessibilityIdentifier("environmentalAnalysisLoading")
            } else if let analysis = analysis {
                ScrollView {
                    VStack(spacing: 20) {
                        qualityCorrelationSection(analysis.qualityCorrelation)
                        environmentalMetricsSection(analysis)
                        recommendationsSection(analysis.recommendations)
                    }
                    .padding()
                }
                .accessibilityIdentifier("environmentalAnalysisScrollView")
            } else if let error = error {
                Text("Analysis Error: \(error.localizedDescription)")
                    .foregroundColor(.red)
                    .accessibilityLabel("Analysis error: \(error.localizedDescription)")
                    .accessibilityIdentifier("environmentalAnalysisError")
            } else {
                Text("No environmental data available")
                    .foregroundColor(.secondary)
                    .accessibilityLabel("No environmental data available for analysis")
                    .accessibilityIdentifier("noEnvironmentalData")
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
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("qualityImpactHeader")
            
            VStack(spacing: 16) {
                correlationRow(
                    label: "Temperature",
                    impact: correlation.temperatureImpact,
                    icon: "thermometer"
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Temperature impact on sleep quality: \(Int(correlation.temperatureImpact * 100)) percent")
                .accessibilityIdentifier("temperatureCorrelationRow")
                
                correlationRow(
                    label: "Humidity",
                    impact: correlation.humidityImpact,
                    icon: "humidity"
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Humidity impact on sleep quality: \(Int(correlation.humidityImpact * 100)) percent")
                .accessibilityIdentifier("humidityCorrelationRow")
                
                correlationRow(
                    label: "Noise",
                    impact: correlation.noiseImpact,
                    icon: "ear"
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Noise impact on sleep quality: \(Int(correlation.noiseImpact * 100)) percent")
                .accessibilityIdentifier("noiseCorrelationRow")
                
                correlationRow(
                    label: "Light",
                    impact: correlation.lightImpact,
                    icon: "lightbulb"
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Light impact on sleep quality: \(Int(correlation.lightImpact * 100)) percent")
                .accessibilityIdentifier("lightCorrelationRow")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("qualityCorrelationSection")
    }
    
    private func correlationRow(label: String, impact: Double, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            
            Text(label)
            
            Spacer()
            
            impactIndicator(score: impact)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) impact: \(Int(impact * 100)) percent")
        .accessibilityIdentifier("correlationRow_\(label.lowercased())")
    }
    
    private func impactIndicator(score: Double) -> some View {
        HStack(spacing: 4) {
            Text(String(format: "%.0f%%", score * 100))
                .foregroundColor(impactColor(score))
            
            Image(systemName: impactIcon(score))
                .foregroundColor(impactColor(score))
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(Int(score * 100)) percent impact")
        .accessibilityIdentifier("impactIndicator")
    }
    
    private func environmentalMetricsSection(_ analysis: EnvironmentalAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Measurements")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("measurementsHeader")
            
            VStack(spacing: 16) {
                metricRow(
                    label: "Temperature",
                    metrics: analysis.temperature,
                    unit: "°C"
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Temperature: average \(String(format: "%.1f", analysis.temperature.average)) degrees, minimum \(String(format: "%.1f", analysis.temperature.minimum)) degrees, maximum \(String(format: "%.1f", analysis.temperature.maximum)) degrees")
                .accessibilityIdentifier("temperatureMetricsRow")
                
                metricRow(
                    label: "Humidity",
                    metrics: analysis.humidity,
                    unit: "%"
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Humidity: average \(String(format: "%.1f", analysis.humidity.average)) percent, minimum \(String(format: "%.1f", analysis.humidity.minimum)) percent, maximum \(String(format: "%.1f", analysis.humidity.maximum)) percent")
                .accessibilityIdentifier("humidityMetricsRow")
                
                metricRow(
                    label: "Noise",
                    metrics: analysis.noise,
                    unit: "dB"
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Noise: average \(String(format: "%.1f", analysis.noise.average)) decibels, minimum \(String(format: "%.1f", analysis.noise.minimum)) decibels, maximum \(String(format: "%.1f", analysis.noise.maximum)) decibels")
                .accessibilityIdentifier("noiseMetricsRow")
                
                metricRow(
                    label: "Light",
                    metrics: analysis.light,
                    unit: "lux"
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Light: average \(String(format: "%.1f", analysis.light.average)) lux, minimum \(String(format: "%.1f", analysis.light.minimum)) lux, maximum \(String(format: "%.1f", analysis.light.maximum)) lux")
                .accessibilityIdentifier("lightMetricsRow")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("environmentalMetricsSection")
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(String(format: "%.1f", value)) \(unit)")
        .accessibilityIdentifier("metricValue_\(label.lowercased())")
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Stability: \(stabilityDescription(variance))")
        .accessibilityIdentifier("varianceIndicator")
    }
    
    private func recommendationsSection(_ recommendations: [EnvironmentalRecommendation]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommendations")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("recommendationsHeader")
            
            if recommendations.isEmpty {
                Text("Environmental conditions are optimal")
                    .font(.subheadline)
                    .foregroundColor(.green)
                    .accessibilityLabel("Environmental conditions are optimal")
                    .accessibilityIdentifier("optimalConditions")
            } else {
                ForEach(recommendations, id: \.description) { recommendation in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "arrow.up.forward")
                            .foregroundColor(.blue)
                            .accessibilityHidden(true)
                        
                        Text(recommendation.description)
                            .font(.subheadline)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Recommendation: \(recommendation.description)")
                    .accessibilityIdentifier("recommendation_\(recommendations.firstIndex(where: { $0.description == recommendation.description }) ?? 0)")
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("recommendationsSection")
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
