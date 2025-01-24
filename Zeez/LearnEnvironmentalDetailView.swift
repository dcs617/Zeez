import SwiftUI

struct LearnEnvironmentalDetailView: View {
    let factor: EnvironmentalFactor
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    factorHeader
                    
                    Divider()
                    
                    optimalRangeSection
                    
                    Divider()
                    
                    impactSection
                    
                    Divider()
                    
                    recommendationsSection
                }
                .padding()
            }
            .navigationTitle(factor.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private var factorHeader: some View {
        HStack {
            Image(systemName: iconName)
                .font(.title)
                .foregroundColor(factorColor)
            
            VStack(alignment: .leading) {
                Text(factor.displayName)
                    .font(.headline)
                Text(getFactorDescription())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var optimalRangeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Optimal Range")
                .font(.headline)
            
            Text("\(formatValue(factor.optimalRange.min)) - \(formatValue(factor.optimalRange.max)) \(unitText)")
                .font(.subheadline)
            
            Text(getOptimalRangeDescription())
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var impactSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Impact on Sleep")
                .font(.headline)
            
            ForEach(getImpactPoints(), id: \.self) { point in
                HStack(alignment: .top) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 8))
                        .padding(.top, 6)
                    Text(point)
                }
            }
        }
    }
    
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recommendations")
                .font(.headline)
            
            ForEach(getRecommendations(), id: \.self) { recommendation in
                HStack(alignment: .top) {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.green)
                    Text(recommendation)
                }
            }
        }
    }
    
    private func formatValue(_ value: Double) -> String {
        factor == .temperature ? String(format: "%.1f", value) : String(format: "%.0f", value)
    }
    
    private var iconName: String {
        switch factor {
        case .temperature: return "thermometer"
        case .light: return "lightbulb.fill"
        case .sound: return "speaker.wave.2.fill"
        }
    }
    
    private var factorColor: Color {
        switch factor {
        case .temperature: return .red
        case .light: return .yellow
        case .sound: return .blue
        }
    }
    
    private var unitText: String {
        switch factor {
        case .temperature: return "°C"
        case .light: return "lux"
        case .sound: return "dB"
        }
    }
    
    private func getFactorDescription() -> String {
        switch factor {
        case .temperature:
            return "Room temperature significantly affects sleep quality"
        case .light:
            return "Light exposure influences your circadian rhythm"
        case .sound:
            return "Noise levels can impact sleep continuity"
        }
    }
    
    private func getOptimalRangeDescription() -> String {
        switch factor {
        case .temperature:
            return "The ideal bedroom temperature for most people"
        case .light:
            return "Darkness is best for sleep, with minimal ambient light"
        case .sound:
            return "Quiet environment with acceptable background noise"
        }
    }
    
    private func getImpactPoints() -> [String] {
        switch factor {
        case .temperature:
            return [
                "Affects core body temperature regulation",
                "Influences sleep onset and maintenance",
                "Impacts REM sleep quality"
            ]
        case .light:
            return [
                "Suppresses melatonin production",
                "Shifts circadian rhythm",
                "Affects sleep-wake cycle"
            ]
        case .sound:
            return [
                "Can cause sleep disruptions",
                "Affects sleep depth and quality",
                "May increase stress levels"
            ]
        }
    }
    
    private func getRecommendations() -> [String] {
        switch factor {
        case .temperature:
            return [
                "Use breathable bedding materials",
                "Adjust temperature before bedtime",
                "Consider seasonal adjustments"
            ]
        case .light:
            return [
                "Use blackout curtains",
                "Avoid blue light before bed",
                "Gradually dim lights in evening"
            ]
        case .sound:
            return [
                "Use white noise if helpful",
                "Consider earplugs if needed",
                "Soundproof room if possible"
            ]
        }
    }
}

extension EnvironmentalFactor {
    var displayName: String {
        switch self {
        case .temperature: return "Temperature"
        case .light: return "Light"
        case .sound: return "Sound"
        }
    }
}

#Preview {
    LearnEnvironmentalDetailView(factor: .temperature)
}