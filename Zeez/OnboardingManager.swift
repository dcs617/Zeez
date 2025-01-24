import SwiftUI
import HealthKit
import UserNotifications

@MainActor
final class OnboardingManager: ObservableObject {
    static let shared = OnboardingManager()
    
    @Published var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
        }
    }
    
    @Published var currentStep: OnboardingStep = .welcome
    @Published var healthKitAuthorized = false
    @Published var notificationsAuthorized = false
    
    private let healthStore = HKHealthStore()
    
    init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        checkExistingPermissions()
    }
    
    func requestHealthKitPermissions() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            ErrorManager.shared.showError(.healthKitNotAvailable)
            return false
        }
        
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .respiratoryRate)!
        ]
        
        let typesToShare: Set<HKSampleType> = [
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        ]
        
        do {
            try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
            await MainActor.run {
                self.healthKitAuthorized = true
            }
            return true
        } catch {
            ErrorManager.shared.reportError(error)
            return false
        }
    }

    func requestNotificationPermissions() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .authorized else {
                let success = try await center.requestAuthorization(options: [.alert, .badge, .sound])
                await MainActor.run {
                    self.notificationsAuthorized = success
                }
                return success
            }
            await MainActor.run {
                self.notificationsAuthorized = true
            }
            return true
        } catch {
            ErrorManager.shared.reportError(error)
            return false
        }
    }
    
    private func checkExistingPermissions() {
        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            
            self.notificationsAuthorized = settings.authorizationStatus == .authorized
            self.healthKitAuthorized = HKHealthStore.isHealthDataAvailable()
        }
    }
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
    }
}

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
