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
    case saveFailed
    case microphonePermissionDenied
    case recordingEndedEarly(savedUntil: Date)
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
             (.insufficientData, .insufficientData),
             (.saveFailed, .saveFailed),
             (.microphonePermissionDenied, .microphonePermissionDenied):
            return true
        case (.recordingEndedEarly(let date1), .recordingEndedEarly(let date2)):
            return date1 == date2
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
            return "Zeez couldn't start the recording"
        case .sleepSessionUpdateFailed:
            return "Zeez couldn't end the recording"
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
        case .saveFailed:
            return "Zeez couldn't save your changes"
        case .microphonePermissionDenied:
            return "Microphone access is off"
        case .recordingEndedEarly:
            return "Your recording stopped early"
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
            return "Please try again."
        case .sleepSessionUpdateFailed:
            return "The recording is still running. Please try ending it again."
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
            return "Free up storage space so Zeez can keep saving your nights."
        case .insufficientData:
            return "Try closing and reopening the app"
        case .saveFailed:
            return "Your last change may not have been saved. Try again, and restart Zeez if it keeps happening."
        case .microphonePermissionDenied:
            return "Zeez needs the microphone to record a night. It measures how loud the room is, and never stores or uploads audio. Turn on Microphone for Zeez in Settings."
        case .recordingEndedEarly(let savedUntil):
            let time = savedUntil.formatted(date: .omitted, time: .shortened)
            return "Zeez was closed during the night, so the recording was saved up to \(time)."
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
    
    /// How the user hears about this error (decision 2026-10-29, `CLAUDE.md` "Error alerts").
    enum Presentation {
        /// `RootView`'s alert, at most once per occurrence.
        case alert
        /// A log line only.
        case log
    }

    /// Alert for a failed save, low storage, a recording that fails to start or end (or ended
    /// early), and the microphone denied when one starts. Everything else — background
    /// scheduling, the badge reset, low battery on foreground, HealthKit and sensor hiccups —
    /// is logged only: nothing the user can act on, or an alert on every foreground.
    var presentation: Presentation {
        switch self {
        case .saveFailed, .storageSpaceLow, .sleepSessionCreationFailed, .sleepSessionUpdateFailed,
             .recordingEndedEarly, .microphonePermissionDenied:
            return .alert
        default:
            return .log
        }
    }

    /// A condition holds until it clears (storage freed), so one occurrence spans every check
    /// that finds it; an event is an occurrence by itself. A Start refused for want of the
    /// microphone is an event: each tap that does nothing has to say why.
    var isCondition: Bool {
        switch self {
        case .storageSpaceLow:
            return true
        default:
            return false
        }
    }

    /// The alert offers Open Settings: the fix is a switch in Zeez's page in Settings.
    var opensSettings: Bool {
        self == .microphonePermissionDenied
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
        case .saveFailed: return "ERR_SAVE"
        case .microphonePermissionDenied: return "ERR_MICROPHONE_PERMISSION"
        case .recordingEndedEarly: return "WARN_RECORDING_ENDED_EARLY"
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
        case .saveFailed: return "save_failed"
        case .microphonePermissionDenied: return "microphone_permission_denied"
        case .recordingEndedEarly: return "recording_ended_early"
        case .generic: return "generic_error"
        case .coreData: return "core_data_error"
        case .network: return "network_error"
        case .user: return "user_error"
        }
    }
}
