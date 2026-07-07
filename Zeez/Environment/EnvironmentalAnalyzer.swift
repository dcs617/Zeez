import CoreData
import Combine
import os.log

/// Analyzes environmental data to provide insights and recommendations
class EnvironmentalAnalyzer {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    /// Analyzes environmental conditions for a sleep session
    /// - Returns: Analysis results including correlations and recommendations
    func analyzeSession(_ session: SleepSession) async throws -> EnvironmentalAnalysis {
        guard let readings = session.environmentalReadings?.allObjects as? [EnvironmentalReading],
              !readings.isEmpty else {
            throw AppError.insufficientData
        }
        
        // Sort readings chronologically
        let sortedReadings = readings.sorted { ($0.timestamp ?? Date()) < ($1.timestamp ?? Date()) }
        
        // Calculate averages and ranges
        let temperature = calculateMetrics(sortedReadings.compactMap { $0.measuredTemperature })
        let humidity = calculateMetrics(sortedReadings.compactMap { $0.measuredHumidity })
        let noise = calculateMetrics(sortedReadings.compactMap { $0.measuredNoiseLevel })
        let light = calculateMetrics(sortedReadings.compactMap { $0.measuredLightLevel })
        
        // Analyze impact on sleep quality
        let qualityCorrelation = try await analyzeQualityCorrelations(
            session: session,
            temp: temperature,
            humidity: humidity,
            noise: noise,
            light: light
        )
        
        // Generate recommendations
        let recommendations = generateRecommendations(
            temperature: temperature,
            humidity: humidity,
            noise: noise,
            light: light,
            correlation: qualityCorrelation
        )
        
        return EnvironmentalAnalysis(
            temperature: temperature,
            humidity: humidity,
            noise: noise,
            light: light,
            qualityCorrelation: qualityCorrelation,
            recommendations: recommendations
        )
    }
    
    /// Finds optimal environmental conditions based on historical data
    func findOptimalConditions() async throws -> OptimalConditions {
        let request = SleepSession.fetchRequest()
        request.predicate = NSPredicate(format: "qualityScore >= 80")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SleepSession.qualityScore, ascending: false)]
        request.fetchLimit = 50 // Analyze top 50 best sessions
        
        let bestSessions = try context.fetch(request)
        
        var temperatures: [Double] = []
        var humidities: [Double] = []
        var noiseLevels: [Double] = []
        var lightLevels: [Double] = []
        
        for session in bestSessions {
            guard let readings = session.environmentalReadings?.allObjects as? [EnvironmentalReading] else {
                continue
            }
            
            // Get average readings for this session
            if let avgTemp = readings.compactMap({ $0.measuredTemperature }).average {
                temperatures.append(avgTemp)
            }
            if let avgHumidity = readings.compactMap({ $0.measuredHumidity }).average {
                humidities.append(avgHumidity)
            }
            if let avgNoise = readings.compactMap({ $0.measuredNoiseLevel }).average {
                noiseLevels.append(avgNoise)
            }
            if let avgLight = readings.compactMap({ $0.measuredLightLevel }).average {
                lightLevels.append(avgLight)
            }
        }
        
        return OptimalConditions(
            temperature: calculateIdealRange(temperatures),
            humidity: calculateIdealRange(humidities),
            noise: calculateIdealRange(noiseLevels),
            light: calculateIdealRange(lightLevels)
        )
    }
    
    // MARK: - Private Methods
    
    private func calculateMetrics(_ values: [Double]) -> EnvironmentalStatistics {
        guard !values.isEmpty else {
            return EnvironmentalStatistics(average: 0, minimum: 0, maximum: 0, variance: 0)
        }
        
        let avg = values.average ?? 0
        let min = values.min() ?? 0
        let max = values.max() ?? 0
        let variance = values.variance ?? 0
        
        return EnvironmentalStatistics(
            average: avg,
            minimum: min,
            maximum: max,
            variance: variance
        )
    }
    
    private func analyzeQualityCorrelations(
        session: SleepSession,
        temp: EnvironmentalStatistics,
        humidity: EnvironmentalStatistics,
        noise: EnvironmentalStatistics,
        light: EnvironmentalStatistics
    ) async throws -> QualityCorrelation {
        // Get optimal conditions for comparison
        let optimal = try await findOptimalConditions()
        
        // Calculate correlation scores (0-1)
        let tempScore = calculateCorrelationScore(
            value: temp.average,
            range: optimal.temperature
        )
        
        let humidityScore = calculateCorrelationScore(
            value: humidity.average,
            range: optimal.humidity
        )
        
        let noiseScore = calculateCorrelationScore(
            value: noise.average,
            range: optimal.noise
        )
        
        let lightScore = calculateCorrelationScore(
            value: light.average,
            range: optimal.light
        )
        
        return QualityCorrelation(
            temperatureImpact: tempScore,
            humidityImpact: humidityScore,
            noiseImpact: noiseScore,
            lightImpact: lightScore
        )
    }
    
    private func calculateCorrelationScore(value: Double, range: ClosedRange<Double>) -> Double {
        if range.contains(value) {
            return 1.0
        }
        
        let midpoint = (range.upperBound + range.lowerBound) / 2
        let maxDeviation = max(
            abs(range.upperBound - midpoint),
            abs(range.lowerBound - midpoint)
        ) * 2
        
        let deviation = abs(value - midpoint)
        return max(0, 1 - (deviation / maxDeviation))
    }
    
    private func calculateIdealRange(_ values: [Double]) -> ClosedRange<Double> {
        guard !values.isEmpty else { return 0...0 }
        
        let sorted = values.sorted()
        let lowerIndex = Int(Double(sorted.count) * 0.25)
        let upperIndex = Int(Double(sorted.count) * 0.75)
        
        return sorted[lowerIndex]...sorted[upperIndex]
    }
    
    private func generateRecommendations(
        temperature: EnvironmentalStatistics,
        humidity: EnvironmentalStatistics,
        noise: EnvironmentalStatistics,
        light: EnvironmentalStatistics,
        correlation: QualityCorrelation
    ) -> [EnvironmentalRecommendation] {
        var recommendations: [EnvironmentalRecommendation] = []
        
        // Temperature recommendations
        if correlation.temperatureImpact < 0.7 {
            if temperature.average > 23 {
                recommendations.append(.lowerTemperature)
            } else if temperature.average < 18 {
                recommendations.append(.raiseTemperature)
            }
        }
        
        // Humidity recommendations
        if correlation.humidityImpact < 0.7 {
            if humidity.average > 60 {
                recommendations.append(.lowerHumidity)
            } else if humidity.average < 30 {
                recommendations.append(.raiseHumidity)
            }
        }
        
        // Noise recommendations
        if correlation.noiseImpact < 0.7 {
            if noise.average > 40 {
                recommendations.append(.reduceNoise)
            }
            if noise.variance > 10 {
                recommendations.append(.reduceSoundVariation)
            }
        }
        
        // Light recommendations
        if correlation.lightImpact < 0.7 {
            if light.average > 10 {
                recommendations.append(.reduceLightLevel)
            }
            if light.variance > 5 {
                recommendations.append(.stabilizeLighting)
            }
        }
        
        return recommendations
    }
}

// MARK: - Supporting Types

struct EnvironmentalAnalysis {
    let temperature: EnvironmentalStatistics
    let humidity: EnvironmentalStatistics
    let noise: EnvironmentalStatistics
    let light: EnvironmentalStatistics
    let qualityCorrelation: QualityCorrelation
    let recommendations: [EnvironmentalRecommendation]
}

struct EnvironmentalStatistics {
    let average: Double
    let minimum: Double
    let maximum: Double
    let variance: Double
}

struct QualityCorrelation {
    let temperatureImpact: Double
    let humidityImpact: Double
    let noiseImpact: Double
    let lightImpact: Double
}

struct OptimalConditions {
    let temperature: ClosedRange<Double>
    let humidity: ClosedRange<Double>
    let noise: ClosedRange<Double>
    let light: ClosedRange<Double>
}

enum EnvironmentalRecommendation {
    case lowerTemperature
    case raiseTemperature
    case lowerHumidity
    case raiseHumidity
    case reduceNoise
    case reduceSoundVariation
    case reduceLightLevel
    case stabilizeLighting
    
    var description: String {
        switch self {
        case .lowerTemperature:
            return "Lower room temperature for better sleep (18-22°C ideal)"
        case .raiseTemperature:
            return "Increase room temperature for comfort (18-22°C ideal)"
        case .lowerHumidity:
            return "Reduce humidity for better sleep comfort (30-60% ideal)"
        case .raiseHumidity:
            return "Increase humidity to prevent dryness (30-60% ideal)"
        case .reduceNoise:
            return "Reduce ambient noise levels (<40 dB ideal)"
        case .reduceSoundVariation:
            return "Minimize sudden sound changes during sleep"
        case .reduceLightLevel:
            return "Reduce light levels for better sleep quality"
        case .stabilizeLighting:
            return "Maintain consistent lighting conditions"
        }
    }
}
