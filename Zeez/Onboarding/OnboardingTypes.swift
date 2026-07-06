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
    /// The only error that can be thrown during onboarding: saving preferences to Core Data.
    /// HealthKit and notification access are optional and never block completion.
    case failedToSave(underlying: Error)

    var alertTitle: String { "Couldn't Save Settings" }

    var errorDescription: String? { "Failed to save your preferences" }

    var recoverySuggestion: String? { "Please try again or restart the app" }

    static func == (lhs: OnboardingError, rhs: OnboardingError) -> Bool {
        if case .failedToSave(let e1) = lhs, case .failedToSave(let e2) = rhs {
            return e1.localizedDescription == e2.localizedDescription
        }
        return false
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
