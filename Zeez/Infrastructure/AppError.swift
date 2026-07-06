import Foundation
import os.log

/// Represents various types of errors that can occur in the app
enum AppError: LocalizedError, Equatable {
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
    case insufficientData
    case generic(Error)
    case coreData(Error)
    case network(Error)
    case user(String)
    
    static func == (lhs: AppError, rhs: AppError) -> Bool {
        switch (lhs, rhs) {
        case (.healthKitPermissionDenied, .healthKitPermissionDenied),
             (.healthKitNotAvailable, .healthKitNotAvailable),
             (.sleepSessionCreationFailed, .sleepSessionCreationFailed),
             (.sleepSessionUpdateFailed, .sleepSessionUpdateFailed),
             (.dataProcessingFailed, .dataProcessingFailed),
             (.backgroundTaskFailed, .backgroundTaskFailed),
             (.sensorDataUnavailable, .sensorDataUnavailable),
             (.watchConnectionLost, .watchConnectionLost),
             (.lowBatteryWarning, .lowBatteryWarning),
             (.storageSpaceLow, .storageSpaceLow),
             (.insufficientData, .insufficientData):
            return true
        case (.generic(let error1), .generic(let error2)):
            return error1.localizedDescription == error2.localizedDescription
        case (.coreData(let error1), .coreData(let error2)):
            return error1.localizedDescription == error2.localizedDescription
        case (.network(let error1), .network(let error2)):
            return error1.localizedDescription == error2.localizedDescription
        case (.user(let message1), .user(let message2)):
            return message1 == message2
        default:
            return false
        }
    }
    
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
        case .insufficientData:
            return "Insufficient analytical data"
        case .generic(let error):
            return error.localizedDescription
        case .coreData(let error):
            return "Database error: \(error.localizedDescription)"
        case .network(let error):
            return "Network error: \(error.localizedDescription)"
        case .user(let message):
            return message
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
        case .insufficientData:
            return "Try closing and reopening the app"
        case .generic:
            return "Try again or contact support if the issue persists"
        case .coreData:
            return "Try restarting the app"
        case .network:
            return "Check your internet connection and try again"
        case .user:
            return nil
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
    
    var code: String {
        switch self {
        case .healthKitPermissionDenied: return "ERR_HEALTHKIT_PERMISSION"
        case .healthKitNotAvailable: return "ERR_HEALTHKIT_UNAVAILABLE"
        case .sleepSessionCreationFailed: return "ERR_SESSION_CREATE"
        case .sleepSessionUpdateFailed: return "ERR_SESSION_UPDATE"
        case .dataProcessingFailed: return "ERR_DATA_PROCESSING"
        case .backgroundTaskFailed: return "ERR_BACKGROUND_TASK"
        case .sensorDataUnavailable: return "ERR_SENSOR_DATA"
        case .watchConnectionLost: return "ERR_WATCH_CONNECTION"
        case .lowBatteryWarning: return "WARN_LOW_BATTERY"
        case .storageSpaceLow: return "WARN_STORAGE_LOW"
        case .insufficientData: return "ERR_INSUFFICIENT_DATA"
        case .generic: return "ERR_GENERIC"
        case .coreData: return "ERR_CORE_DATA"
        case .network: return "ERR_NETWORK"
        case .user: return "ERR_USER"
        }
    }
    
    var name: String {
        switch self {
        case .healthKitPermissionDenied: return "healthkit_permission_denied"
        case .healthKitNotAvailable: return "healthkit_unavailable"
        case .sleepSessionCreationFailed: return "session_creation_failed"
        case .sleepSessionUpdateFailed: return "session_update_failed"
        case .dataProcessingFailed: return "data_processing_failed"
        case .backgroundTaskFailed: return "background_task_failed"
        case .sensorDataUnavailable: return "sensor_data_unavailable"
        case .watchConnectionLost: return "watch_connection_lost"
        case .lowBatteryWarning: return "low_battery_warning"
        case .storageSpaceLow: return "storage_space_low"
        case .insufficientData: return "insufficient_data"
        case .generic: return "generic_error"
        case .coreData: return "core_data_error"
        case .network: return "network_error"
        case .user: return "user_error"
        }
    }
}
