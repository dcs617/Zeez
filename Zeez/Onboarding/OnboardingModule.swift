import SwiftUI
import HealthKit
import UserNotifications
import CoreData
import os.log

// MARK: - Dependencies & Environment
// These components coordinate the onboarding experience

// MARK: - Module Configuration
extension OnboardingManager {
    /// Configure default values for the onboarding experience
    static func configure(
        defaultSleepDuration: Double = OnboardingDefaults.sleepDuration,
        defaultWakeHour: Int = OnboardingDefaults.wakeHour,
        defaultWakeMinute: Int = OnboardingDefaults.wakeMinute
    ) {
        OnboardingDefaults.sleepDuration = defaultSleepDuration
        OnboardingDefaults.wakeHour = defaultWakeHour
        OnboardingDefaults.wakeMinute = defaultWakeMinute
    }
}
