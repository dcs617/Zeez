import SwiftUI
import HealthKit
import UserNotifications
import CoreData
import os.log

@MainActor
final class OnboardingManager: ObservableObject {
    // MARK: - Singleton
    static let shared = OnboardingManager()
    
    // MARK: - Published Properties
    @Published private(set) var currentStep: OnboardingStep = .welcome
    @Published private(set) var isTransitioning = false
    @Published private(set) var healthKitAuthorized = false
    @Published private(set) var notificationsAuthorized = false
    @Published private(set) var activeError: OnboardingError?
    @Published var showErrorAlert = false
    @Published private(set) var hasCompletedOnboarding: Bool
    
    // Sleep goal settings
    @Published var targetSleepDuration: Double {
        didSet {
            Task { @MainActor in
                triggerSelectionFeedback()
            }
        }
    }
    
    @Published var targetWakeTime: Date {
        didSet {
            Task { @MainActor in
                triggerSelectionFeedback()
            }
        }
    }
    
    // MARK: - Private Properties
    private let healthStore = HKHealthStore()
    private let context: NSManagedObjectContext
    private let defaults = UserDefaults.standard
    
    // MARK: - Initialization
    private init() {
        self.context = PersistenceController.shared.container.viewContext
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: OnboardingDefaults.userDefaultsKey)
        self.targetSleepDuration = OnboardingDefaults.sleepDuration
        self.targetWakeTime = Calendar.current.date(
            bySettingHour: OnboardingDefaults.wakeHour,
            minute: OnboardingDefaults.wakeMinute,
            second: 0,
            of: Date()
        ) ?? Date()
        
        Task { @MainActor in
            await checkExistingPermissions()
        }
    }
    
    // MARK: - Public Methods
    func moveToNextStep() {
        Task { @MainActor in
            do {
                isTransitioning = true
                defer { isTransitioning = false }
                
                switch currentStep {
                case .healthKit:
                    try await requestHealthKitPermissions()
                case .notifications:
                    try await requestNotificationPermissions()
                case .completion:
                    try await savePreferences()
                    completeOnboarding()
                default:
                    await proceedToNextStep()
                }
            } catch let error as OnboardingError {
                handleError(error)
            } catch {
                handleError(.failedToSave(underlying: error))
            }
        }
    }
    
    // MARK: - Private Methods
    private func checkExistingPermissions() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        
        self.notificationsAuthorized = settings.authorizationStatus == .authorized
        self.healthKitAuthorized = HKHealthStore.isHealthDataAvailable()
    }
    
    private func requestHealthKitPermissions() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw OnboardingError.healthKitNotAvailable
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
            self.healthKitAuthorized = true
            await proceedToNextStep()
        } catch {
            throw OnboardingError.healthKitPermissionDenied
        }
    }
    
    private func requestNotificationPermissions() async throws {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        
        if settings.authorizationStatus == .denied {
            throw OnboardingError.notificationsPermissionDenied
        }
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            self.notificationsAuthorized = granted
            if granted {
                await proceedToNextStep()
            } else {
                throw OnboardingError.notificationsPermissionDenied
            }
        } catch {
            throw OnboardingError.notificationsPermissionDenied
        }
    }
    
    private func savePreferences() async throws {
        let preferences = UserPreferences(context: context)
        preferences.id = UUID()
        preferences.targetSleepDuration = targetSleepDuration * 3600 // Convert to seconds
        preferences.targetWakeTime = targetWakeTime
        preferences.targetBedtime = Calendar.current.date(
            byAdding: .hour,
            value: -Int(targetSleepDuration),
            to: targetWakeTime
        )
        preferences.sleepGoalEnabled = true
        preferences.healthKitSyncEnabled = healthKitAuthorized
        preferences.notificationsEnabled = notificationsAuthorized
        preferences.createdAt = Date()
        preferences.modifiedAt = Date()
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                throw OnboardingError.failedToSave(underlying: error)
            }
        }
    }
    
    private func proceedToNextStep() async {
        let allSteps = OnboardingStep.allCases
        guard let currentIndex = allSteps.firstIndex(of: currentStep),
              currentIndex < allSteps.count - 1 else {
            return
        }
        
        triggerHapticFeedback()
        withAnimation(OnboardingAnimation.spring) {
            currentStep = allSteps[currentIndex + 1]
        }
    }
    
    private func completeOnboarding() {
        hasCompletedOnboarding = true
        defaults.set(true, forKey: OnboardingDefaults.userDefaultsKey)
        triggerHapticFeedback()
    }
    
    private func handleError(_ error: OnboardingError) {
        triggerErrorFeedback()
        activeError = error
        showErrorAlert = true
        ZeezLogger.error(ZeezLogger.app, "Onboarding error: \(error.localizedDescription)")
        if let suggestion = error.recoverySuggestion {
            ZeezLogger.info(ZeezLogger.app, "Recovery suggestion: \(suggestion)")
        }
    }
    
    #if os(iOS)
    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    #endif
}
