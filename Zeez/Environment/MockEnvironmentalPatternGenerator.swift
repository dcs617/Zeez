import Foundation
import os.log

/// Helper struct for generating realistic environmental patterns for mock data
struct MockEnvironmentalPatternGenerator {
    struct Reading {
        let temperature: Double
        let humidity: Double
        let noise: Double
        let light: Double
    }
    
    /// Optimal ranges for sleep environment
    static let optimalRanges = (
        temperature: 18.0...22.0,
        humidity: 40.0...60.0,
        noise: 20.0...40.0,
        light: 0.0...5.0
    )
    
    /// Generate a base environmental reading with natural variation
    static func generateBaseReading() -> Reading {
        Reading(
            temperature: Double.random(in: optimalRanges.temperature),
            humidity: Double.random(in: optimalRanges.humidity),
            noise: Double.random(in: optimalRanges.noise),
            light: Double.random(in: optimalRanges.light)
        )
    }
    
    /// Add time-based variations to the base reading
    static func addTimeVariation(to reading: Reading, at time: Date) -> Reading {
        let hour = Calendar.current.component(.hour, from: time)
        let minute = Calendar.current.component(.minute, from: time)
        let timeOfDay = Double(hour) + Double(minute) / 60.0
        
        // Temperature varies sinusoidally through the day
        let tempVariation = sin((timeOfDay - 14) * .pi / 12) * 2
        
        // Light variation based on time
        let lightVariation = if hour >= 6 && hour <= 18 {
            Double.random(in: 50...200) // Daylight
        } else if hour >= 19 && hour <= 20 {
            Double.random(in: 10...50)  // Sunset
        } else {
            Double.random(in: 0...10)   // Night
        }
        
        // Noise variation based on time
        let noiseVariation = if hour >= 7 && hour <= 22 {
            Double.random(in: 5...15)   // Daytime
        } else {
            Double.random(in: 0...5)    // Night
        }
        
        return Reading(
            temperature: reading.temperature + tempVariation,
            humidity: reading.humidity + Double.random(in: -5...5),
            noise: reading.noise + noiseVariation,
            light: lightVariation
        )
    }
    
    /// Calculate environmental score based on readings
    static func calculateScore(reading: Reading) -> Double {
        var score = 100.0
        
        // Temperature impact
        if !optimalRanges.temperature.contains(reading.temperature) {
            let deviation = min(
                abs(reading.temperature - optimalRanges.temperature.lowerBound),
                abs(reading.temperature - optimalRanges.temperature.upperBound)
            )
            score -= deviation * 5
        }
        
        // Humidity impact
        if !optimalRanges.humidity.contains(reading.humidity) {
            let deviation = min(
                abs(reading.humidity - optimalRanges.humidity.lowerBound),
                abs(reading.humidity - optimalRanges.humidity.upperBound)
            )
            score -= deviation * 2
        }
        
        // Noise impact
        if !optimalRanges.noise.contains(reading.noise) {
            let deviation = reading.noise - optimalRanges.noise.upperBound
            if deviation > 0 {
                score -= deviation * 3
            }
        }
        
        // Light impact
        if !optimalRanges.light.contains(reading.light) {
            let deviation = reading.light - optimalRanges.light.upperBound
            if deviation > 0 {
                score -= deviation * 4
            }
        }
        
        return max(0, min(100, score))
    }
}
