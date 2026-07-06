import SwiftUI
import HealthKit
import UserNotifications
import WatchConnectivity
import CoreData
import os.log

@MainActor
final class OnboardingManager: ObservableObject {
    // MARK: - Singleton
    static let shared = OnboardingManager()

    // MARK: - Published Properties
    @Published private(set) var currentStep: OnboardingStep = .welcome
    @Published private(set) var isTransitioning = false
    /// True once the HealthKit authorization sheet was shown this session.
    /// NOTE: Apple Health read permission status cannot be queried by API (privacy by design),
    /// so this flag only reflects whether the dialog was presented — not what was granted.
    @Published private(set) var healthKitSetupCompleted = false
    @Published private(set) var notificationsAuthorized = false
    @Published private(set) var activeError: OnboardingError?
    @Published var showErrorAlert = false
    @Published private(set) var hasCompletedOnboarding: Bool

    // Sleep goal settings — value is in hours (6…10); stored to Core Data as seconds
    @Published var targetSleepHours: Double {
        didSet { Task { @MainActor in triggerSelectionFeedback() } }
    }

    @Published var targetWakeTime: Date {
        didSet { Task { @MainActor in triggerSelectionFeedback() } }
    }

    // MARK: - Private Properties
    private let healthStore = HKHealthStore()
    private let context: NSManagedObjectContext
    private let defaults = UserDefaults.standard

    // MARK: - Computed Properties
    var healthKitAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    // MARK: - Bedtime Helper
    /// Single source of truth for the bedtime formula.
    /// Using TimeInterval arithmetic preserves fractional hours (e.g. 7.5h → 11:30 PM, not midnight).
    static func computeBedtime(wakeTime: Date, sleepHours: Double) -> Date {
        wakeTime.addingTimeInterval(-sleepHours * 3600)
    }

    // MARK: - Initialization
    private init() {
        self.context = PersistenceController.shared.container.viewContext

        #if DEBUG
        if CommandLine.arguments.contains("-uiTestCompletedOnboarding") {
            self.hasCompletedOnboarding = true
        } else if CommandLine.arguments.contains("-uiTestResetOnboarding") {
            self.hasCompletedOnboarding = false
        } else {
            self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: OnboardingDefaults.userDefaultsKey)
        }
        #else
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: OnboardingDefaults.userDefaultsKey)
        #endif

        self.targetSleepHours = OnboardingDefaults.sleepDuration
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

    /// Reset singleton state for testing
    func reset() {
        currentStep = .welcome
        isTransitioning = false
        healthKitSetupCompleted = false
        notificationsAuthorized = false
        activeError = nil
        showErrorAlert = false
        hasCompletedOnboarding = false
        targetSleepHours = OnboardingDefaults.sleepDuration
        targetWakeTime = Calendar.current.date(
            bySettingHour: OnboardingDefaults.wakeHour,
            minute: OnboardingDefaults.wakeMinute,
            second: 0,
            of: Date()
        ) ?? Date()
    }

    // MARK: - Public Methods
    var canGoBack: Bool { currentStep != .welcome }

    func moveToPreviousStep() {
        let allSteps = OnboardingStep.allCases
        guard let currentIndex = allSteps.firstIndex(of: currentStep), currentIndex > 0 else { return }
        triggerHapticFeedback()
        withAnimation(OnboardingAnimation.spring) {
            currentStep = allSteps[currentIndex - 1]
        }
    }

    func moveToNextStep() {
        Task { @MainActor in
            do {
                isTransitioning = true
                defer { isTransitioning = false }

                switch currentStep {
                case .healthKit:
                    await requestHealthKitPermissions()
                case .notifications:
                    await requestNotificationPermissions()
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
        notificationsAuthorized = settings.authorizationStatus == .authorized
        // healthKitSetupCompleted is session-scoped: starts false, set to true when the
        // authorization dialog is presented. We cannot query read-grant status via HK API.
    }

    private func requestHealthKitPermissions() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            // HealthKit unavailable (e.g., iPad) — advance without requesting.
            await proceedToNextStep()
            return
        }

        // Read-only: the app imports data from Apple Health; it never writes back.
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .respiratoryRate)!
        ]

        do {
            try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
            // Only mark complete when the request presented without a system-level error.
            // Read grant status is intentionally unknowable via HealthKit API (privacy by design).
            healthKitSetupCompleted = true
        } catch {
            // requestAuthorization throws only on system-level failure, not user denial.
            // Leave healthKitSetupCompleted = false so the completion screen doesn't claim success.
            ZeezLogger.error(ZeezLogger.app, "HealthKit authorization request failed", error: error)
        }

        await proceedToNextStep()
    }

    private func requestNotificationPermissions() async {
        let center = UNUserNotificationCenter.current()
        let current = await center.notificationSettings()

        if current.authorizationStatus == .notDetermined {
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
                notificationsAuthorized = granted
            } catch {
                // System-level failure — leave notificationsAuthorized = false and advance.
                // This must not surface as a "Couldn't Save Settings" alert.
                ZeezLogger.error(ZeezLogger.app, "Notification authorization request failed", error: error)
            }
        } else {
            notificationsAuthorized = current.authorizationStatus == .authorized
        }
        // Notifications are optional — advance regardless of grant outcome
        await proceedToNextStep()
    }

    private func savePreferences() async throws {
        let request: NSFetchRequest<UserPreferences> = UserPreferences.fetchRequest()
        request.fetchLimit = 1
        let existing = try? context.fetch(request).first
        let preferences = existing ?? UserPreferences(context: context)

        if preferences.id == nil { preferences.id = UUID() }
        preferences.targetSleepDuration = targetSleepHours * 3600 // store as seconds
        preferences.targetWakeTime = targetWakeTime
        preferences.targetBedtime = OnboardingManager.computeBedtime(
            wakeTime: targetWakeTime, sleepHours: targetSleepHours
        )
        preferences.sleepGoalEnabled = true
        preferences.healthKitSyncEnabled = healthKitSetupCompleted
        preferences.notificationsEnabled = notificationsAuthorized
        if preferences.createdAt == nil { preferences.createdAt = Date() }
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
              currentIndex < allSteps.count - 1 else { return }
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
