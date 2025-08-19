import SwiftUI
import Charts
import os.log

extension SleepQualityView {
    func sleepStagesSection(stages: [SleepStage]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleep Stages")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("sleepStagesHeader")
            
            let stageData = calculateStageDistribution(stages)
            VStack(spacing: 16) {
                Chart(stageData, id: \.stage) { data in
                    SectorMark(
                        angle: .value("Time", data.duration),
                        innerRadius: .ratio(0.618),
                        angularInset: 1.5
                    )
                    .cornerRadius(4)
                    .foregroundStyle(by: .value("Stage", data.stage))
                }
                .frame(height: 200)
                .chartForegroundStyleScale([
                    "Light": Color.blue,
                    "Deep": Color.indigo,
                    "REM": Color.purple,
                    "Awake": Color.orange
                ])
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Sleep stages distribution chart showing \(generateStagesSummary(stageData))")
                .accessibilityHint("Chart displaying time spent in each sleep stage during the night")
                .accessibilityIdentifier("sleepStagesChart")
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sleepStagesSection")
    }
    
    func environmentSection(readings: [EnvironmentalReading]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleep Environment")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("environmentHeader")
            
            let avgReading = calculateAverageReading(readings)
            LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 16) {
                EnvironmentMetricView(
                    icon: "thermometer",
                    label: "Temperature",
                    value: String(format: "%.1f°C", avgReading.temperature),
                    rating: ratingFor(temperature: avgReading.temperature)
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Temperature \(String(format: "%.1f degrees celsius", avgReading.temperature)), rating \(ratingFor(temperature: avgReading.temperature))")
                .accessibilityIdentifier("temperatureMetric")
                
                EnvironmentMetricView(
                    icon: "humidity.fill",
                    label: "Humidity",
                    value: String(format: "%.0f%%", avgReading.humidity),
                    rating: ratingFor(humidity: avgReading.humidity)
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Humidity \(String(format: "%.0f percent", avgReading.humidity)), rating \(ratingFor(humidity: avgReading.humidity))")
                .accessibilityIdentifier("humidityMetric")
                
                EnvironmentMetricView(
                    icon: "sun.max.fill",
                    label: "Light",
                    value: String(format: "%.0f lux", avgReading.light),
                    rating: ratingFor(light: avgReading.light)
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Light level \(String(format: "%.0f lux", avgReading.light)), rating \(ratingFor(light: avgReading.light))")
                .accessibilityIdentifier("lightMetric")
                
                EnvironmentMetricView(
                    icon: "speaker.wave.2.fill",
                    label: "Noise",
                    value: String(format: "%.0f dB", avgReading.noise),
                    rating: ratingFor(noise: avgReading.noise)
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Noise level \(String(format: "%.0f decibels", avgReading.noise)), rating \(ratingFor(noise: avgReading.noise))")
                .accessibilityIdentifier("noiseMetric")
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("environmentSection")
    }
    
    var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommendations")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("recommendationsHeader")
            
            VStack(spacing: 16) {
                ForEach(Array(generateRecommendations().enumerated()), id: \.element.title) { index, rec in
                    RecommendationRow(
                        icon: rec.icon,
                        title: rec.title,
                        description: rec.description,
                        color: rec.color
                    )
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(rec.title): \(rec.description)")
                    .accessibilityHint("Recommendation \(index + 1) of \(generateRecommendations().count) for improving your sleep quality")
                    .accessibilityIdentifier("recommendation_\(index)")
                }
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("recommendationsSection")
    }
    
    // MARK: - Helper Methods
    
    private func calculateStageDistribution(_ stages: [SleepStage]) -> [(stage: String, duration: TimeInterval)] {
        var stageDurations: [String: TimeInterval] = [:]
        let totalDuration = stages.reduce(0.0) { $0 + $1.duration }
        
        stages.forEach { stage in
            if let type = stage.stageType {
                stageDurations[type, default: 0] += stage.duration
            }
        }
        
        // Sort by duration for consistent display order
        let sortedDistribution = stageDurations.map { (stage: $0.key, duration: $0.value) }
            .sorted { $0.duration > $1.duration }
        
        // Log distribution for debugging if total duration is significant
        if totalDuration > 3600 { // More than 1 hour
            ZeezLogger.sleepTracking.debug("Sleep stage distribution calculated: \(stageDurations)")
        }
        
        return sortedDistribution
    }
    
    private func calculateAverageReading(_ readings: [EnvironmentalReading]) -> (temperature: Double, humidity: Double, light: Double, noise: Double) {
        let count = Double(readings.count)
        let summed = readings.reduce(into: (temp: 0.0, hum: 0.0, light: 0.0, noise: 0.0)) { result, reading in
            result.temp += reading.temperature
            result.hum += reading.humidity
            result.light += reading.lightLevel
            result.noise += reading.noiseLevel
        }
        
        return (
            temperature: summed.temp / count,
            humidity: summed.hum / count,
            light: summed.light / count,
            noise: summed.noise / count
        )
    }
    
    private func ratingFor(temperature: Double) -> String {
        switch temperature {
        case 18...22: return "Optimal"
        case 16...24: return "Good"
        default: return "Fair"
        }
    }
    
    private func ratingFor(humidity: Double) -> String {
        switch humidity {
        case 30...50: return "Optimal"
        case 25...60: return "Good"
        default: return "Fair"
        }
    }
    
    private func ratingFor(light: Double) -> String {
        switch light {
        case 0...5: return "Optimal"
        case 6...10: return "Good"
        default: return "Fair"
        }
    }
    
    private func ratingFor(noise: Double) -> String {
        switch noise {
        case 0...30: return "Optimal"
        case 31...40: return "Good"
        default: return "Fair"
        }
    }
    
    private func generateRecommendations() -> [(icon: String, title: String, description: String, color: Color)] {
        var recommendations: [(icon: String, title: String, description: String, color: Color)] = []
        
        guard let session = session else { return [] }
        
        // Check sleep duration
        if session.timeInSleep < AppConstants.Sleep.qualityWarningThreshold {
            recommendations.append((
                icon: "moon.circle.fill",
                title: "Sleep Duration",
                description: "Try to get at least 7 hours of sleep for optimal rest",
                color: .blue
            ))
        }
        
        // Check environmental factors
        if let readings = session.environmentalReadings?.allObjects as? [EnvironmentalReading],
           let lastReading = readings.last {
            if lastReading.temperature > 22 {
                recommendations.append((
                    icon: "thermometer.sun.fill",
                    title: "Room Temperature",
                    description: "Consider lowering room temperature to 18-22°C for better sleep",
                    color: .orange
                ))
            }
            
            if lastReading.lightLevel > 5 {
                recommendations.append((
                    icon: "sun.max.fill",
                    title: "Light Level",
                    description: "Your room could be darker. Consider using blackout curtains",
                    color: .yellow
                ))
            }
        }
        
        // Always provide at least one recommendation
        if recommendations.isEmpty {
            recommendations.append((
                icon: "star.fill",
                title: "Keep it up!",
                description: "You're maintaining good sleep habits. Keep the consistency!",
                color: .green
            ))
        }
        
        return recommendations
    }
    
    private func generateStagesSummary(_ stageData: [(stage: String, duration: TimeInterval)]) -> String {
        let sortedData = stageData.sorted { $0.duration > $1.duration }
        let totalDuration = stageData.reduce(0) { $0 + $1.duration }
        
        guard totalDuration > 0 else { return "no sleep stage data available" }
        
        return sortedData.map { stage in
            let percentage = Int((stage.duration / totalDuration) * 100)
            return "\(percentage)% \(stage.stage) sleep"
        }.joined(separator: ", ")
    }
}
