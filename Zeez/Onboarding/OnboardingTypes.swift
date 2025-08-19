import Foundation
import SwiftUI
import os.log

enum OnboardingStep: Identifiable, CaseIterable {
    case welcome
    case healthKit
    case notifications
    case watchPairing
    case sleepGoal
    case completion
    
    var id: Self { self }
    
    var title: String {
        switch self {
        case .welcome: return "Welcome to Zeez"
        case .healthKit: return "Health Integration"
        case .notifications: return "Stay Updated"
        case .watchPairing: return "Connect Watch"
        case .sleepGoal: return "Set Sleep Goal"
        case .completion: return "All Set!"
        }
    }
    
    var description: String {
        switch self {
        case .welcome:
            return "Let's get you set up for better sleep tracking and insights."
        case .healthKit:
            return "Connect to Apple Health to track your sleep and health data."
        case .notifications:
            return "Get notified about your sleep schedule and insights."
        case .watchPairing:
            return "Use your Apple Watch for enhanced sleep tracking."
        case .sleepGoal:
            return "Set your sleep goals for optimal rest."
        case .completion:
            return "You're ready to start tracking better sleep!"
        }
    }
    
    var systemImage: String {
        switch self {
        case .welcome: return "moon.stars.fill"
        case .healthKit: return "heart.fill"
        case .notifications: return "bell.fill"
        case .watchPairing: return "applewatch"
        case .sleepGoal: return "bed.double.fill"
        case .completion: return "checkmark.circle.fill"
        }
    }
}

enum OnboardingError: LocalizedError, Equatable {
    case healthKitNotAvailable
    case healthKitPermissionDenied
    case notificationsPermissionDenied
    case failedToSave(underlying: Error)
    
    var errorDescription: String? {
        switch self {
        case .healthKitNotAvailable:
            return "Health data is not available on this device"
        case .healthKitPermissionDenied:
            return "Health access is required for sleep tracking"
        case .notificationsPermissionDenied:
            return "Notifications are required for sleep reminders"
        case .failedToSave:
            return "Failed to save your preferences"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .healthKitNotAvailable:
            return "Please try using a device that supports HealthKit"
        case .healthKitPermissionDenied:
            return "You can enable Health access in Settings"
        case .notificationsPermissionDenied:
            return "You can enable notifications in Settings"
        case .failedToSave:
            return "Please try again or contact support if the issue persists"
        }
    }
    
    static func == (lhs: OnboardingError, rhs: OnboardingError) -> Bool {
        switch (lhs, rhs) {
        case (.healthKitNotAvailable, .healthKitNotAvailable),
             (.healthKitPermissionDenied, .healthKitPermissionDenied),
             (.notificationsPermissionDenied, .notificationsPermissionDenied):
            return true
        case (.failedToSave(let error1), .failedToSave(let error2)):
            return error1.localizedDescription == error2.localizedDescription
        default:
            return false
        }
    }
}

enum OnboardingDefaults {
    static let userDefaultsKey = "hasCompletedOnboarding"
    static var sleepDuration: Double = 8.0
    static var wakeHour: Int = 7
    static var wakeMinute: Int = 0
}

enum OnboardingAnimation {
    static let spring = Animation.spring(response: 0.5, dampingFraction: 0.8)
    static let slideTransition = AnyTransition.asymmetric(
        insertion: .move(edge: .trailing),
        removal: .move(edge: .leading)
    )
}
