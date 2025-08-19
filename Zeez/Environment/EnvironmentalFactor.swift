import SwiftUI
import os.log

/// Represents different environmental factors that affect sleep quality
/// Used throughout the app to track, analyze and display environmental conditions
enum EnvironmentalFactor: String, CaseIterable, Identifiable {
    case temperature = "Temperature"
    case light = "Light"
    case sound = "Sound"
    
    /// Unique identifier to conform to Identifiable
    var id: String { rawValue }
    
    /// SF Symbol icon name for each environmental factor
    var icon: String {
        switch self {
        case .temperature:
            return "thermometer"
        case .light:
            return "lightbulb.fill"
        case .sound:
            return "speaker.wave.2.fill"
        }
    }
    
    /// Theme color associated with each factor
    var color: Color {
        switch self {
        case .temperature:
            return .red
        case .light:
            return .yellow
        case .sound:
            return .blue
        }
    }
    
    /// Measurement unit for each factor
    var unit: String {
        switch self {
        case .temperature:
            return "°C"
        case .light:
            return "lux"
        case .sound:
            return "dB"
        }
    }
    
    /// The total possible range for measurements of this factor
    var range: (min: Double, max: Double) {
        switch self {
        case .temperature:
            return (15, 25)  // in Celsius
        case .light:
            return (0, 100)  // in lux
        case .sound:
            return (0, 60)   // in dB
        }
    }
    
    /// The ideal range for optimal sleep conditions
    var optimalRange: (min: Double, max: Double) {
        switch self {
        case .temperature:
            return (18, 21)  // in Celsius
        case .light:
            return (0, 5)    // in lux
        case .sound:
            return (0, 30)   // in dB
        }
    }
}
