import Foundation

/// Represents various types of errors that can occur in the app
enum AppError: LocalizedError {
    case healthKitPermissionDenied
    case healthKitNotAvailable
    case sleepSessionCreationFailed
    case sleepSessionUpdateFailed
    case dataProcessingFailed
    case backgroundTaskFailed
    case sensorDataUnavailable
    case watchConnectionLost
    case lowBatteryWarning
    case storageSpaceLow
    
    var errorDescription: String? {
        switch self {
        case .healthKitPermissionDenied:
            return "Health data access is required for sleep tracking"
        case .healthKitNotAvailable:
            return "HealthKit is not available on this device"
        case .sleepSessionCreationFailed:
            return "Unable to create sleep session"
        case .sleepSessionUpdateFailed:
            return "Unable to update sleep session"
        case .dataProcessingFailed:
            return "Error processing sleep data"
        case .backgroundTaskFailed:
            return "Background processing interrupted"
        case .sensorDataUnavailable:
            return "Unable to access sensor data"
        case .watchConnectionLost:
            return "Apple Watch connection lost"
        case .lowBatteryWarning:
            return "Battery level is low"
        case .storageSpaceLow:
            return "Storage space is running low"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .healthKitPermissionDenied:
            return "Please enable Health access in Settings"
        case .healthKitNotAvailable:
            return "Sleep tracking requires an iPhone with HealthKit support"
        case .sleepSessionCreationFailed:
            return "Please try starting a new sleep session"
        case .sleepSessionUpdateFailed:
            return "Please try saving your session again"
        case .dataProcessingFailed:
            return "Try closing and reopening the app"
        case .backgroundTaskFailed:
            return "Make sure background app refresh is enabled"
        case .sensorDataUnavailable:
            return "Check device sensors and permissions"
        case .watchConnectionLost:
            return "Make sure your Apple Watch is nearby and connected"
        case .lowBatteryWarning:
            return "Connect your device to a power source"
        case .storageSpaceLow:
            return "Free up storage space to continue tracking sleep"
        }
    }
    
    var isWarning: Bool {
        switch self {
        case .lowBatteryWarning, .storageSpaceLow:
            return true
        default:
            return false
        }
    }
}