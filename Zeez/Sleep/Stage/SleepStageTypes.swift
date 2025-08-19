import Foundation
import os.log

/// Defines the different types of sleep stages tracked by the app
enum SleepStageType: String, CaseIterable {
    case awake = "AWAKE"
    case lightSleep = "LIGHT"
    case deepSleep = "DEEP"
    case rem = "REM"
    
    var displayName: String {
        switch self {
        case .awake: return "Awake"
        case .lightSleep: return "Light Sleep"
        case .deepSleep: return "Deep Sleep"
        case .rem: return "REM Sleep"
        }
    }
    
    var description: String {
        switch self {
        case .awake:
            return "Brief periods of wakefulness during sleep cycle"
        case .lightSleep:
            return "Initial stage of sleep where you're easily awakened"
        case .deepSleep:
            return "Restorative phase important for physical recovery"
        case .rem:
            return "Rapid Eye Movement sleep, crucial for cognitive function"
        }
    }
}
