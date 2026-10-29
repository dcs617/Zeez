import Testing
import CoreData
import Foundation
@testable import Zeez

/// Which errors reach the user, and how often (decision 2026-10-29).
///
/// Until then nothing presented `ErrorManager`'s errors, and its policy, had one existed, was
/// "show every `AppError`": low battery on every foreground, background-scheduling failures,
/// HealthKit hiccups. A failed viewContext save, a Core Data error rather than an `AppError`,
/// was dropped instead. Now `AppError.presentation` decides, and `RootView` presents
/// `currentAlert`, at most once per occurrence.
@Suite("Error alert policy", .serialized) @MainActor
struct ErrorAlertPolicyTests {

    private static let alerted: [AppError] = [
        .saveFailed, .storageSpaceLow, .sleepSessionCreationFailed, .sleepSessionUpdateFailed,
        .recordingEndedEarly(savedUntil: Date(timeIntervalSince1970: 1_800_000_000)),
        .microphonePermissionDenied
    ]

    private static let logged: [AppError] = [
        .lowBatteryWarning, .backgroundTaskFailed, .healthKitPermissionDenied, .healthKitNotAvailable,
        .dataProcessingFailed, .sensorDataUnavailable, .watchConnectionLost, .insufficientData,
        .user("anything")
    ]

    private func status(battery: Float = 0.9, storage: UInt64 = 10_000_000_000) -> ResourceMonitor.ResourceStatus {
        ResourceMonitor.ResourceStatus(batteryLevel: battery, thermalState: .nominal, lowPowerModeEnabled: false,
                                       availableMemory: 1_000_000_000, availableStorage: storage)
    }

    @Test("Every error the policy names reaches the alert")
    func alertedErrorsPresent() {
        for error in Self.alerted {
            let errors = ErrorManager()
            errors.report(error)
            #expect(errors.currentAlert == error, "\(error.code) should alert")
        }
    }

    @Test("Background scheduling, low battery, HealthKit and sensor errors are logged only")
    func loggedErrorsNeverPresent() {
        for error in Self.logged {
            let errors = ErrorManager()
            errors.report(error)
            #expect(errors.currentAlert == nil, "\(error.code) should be a log line, not an alert")
            #expect(errors.pendingAlerts.isEmpty)
        }
    }

    @Test("Low battery on foreground is a log line")
    func lowBatteryOnForegroundDoesNotAlert() {
        let errors = ErrorManager()
        BackgroundTaskManager.reportResources(status(battery: 0.05), to: errors)
        #expect(errors.currentAlert == nil)
    }

    @Test("An unknown battery level (-1, the simulator) is not a low battery")
    func unknownBatteryIsNotLow() {
        let errors = ErrorManager()
        BackgroundTaskManager.reportResources(status(battery: -1), to: errors)
        #expect(errors.currentAlert == nil)
    }

    @Test("Low storage alerts once per occurrence, and again once it has cleared and come back")
    func lowStorageAlertsOncePerOccurrence() {
        let errors = ErrorManager()
        BackgroundTaskManager.reportResources(status(storage: 1_000), to: errors)
        #expect(errors.currentAlert == .storageSpaceLow)
        errors.dismissAlert()

        // The next foreground finds the same shortage: the same occurrence.
        BackgroundTaskManager.reportResources(status(storage: 1_000), to: errors)
        #expect(errors.currentAlert == nil)
        #expect(errors.pendingAlerts.isEmpty, "The same shortage must not alert on every foreground")

        // Space was freed, then ran out again: a new occurrence.
        BackgroundTaskManager.reportResources(status(), to: errors)
        BackgroundTaskManager.reportResources(status(storage: 1_000), to: errors)
        #expect(errors.currentAlert == .storageSpaceLow)
    }

    @Test("A failed viewContext save alerts")
    func failedLifecycleSaveAlerts() {
        let context = PersistenceController(inMemory: true).container.viewContext
        let session = SleepSession(context: context)
        session.id = UUID()
        session.qualityScore = 500 // above the model's maximum of 100, so the save fails validation

        let errors = ErrorManager()
        SceneDelegate.saveIfNeeded(context, reportingTo: errors)
        #expect(errors.currentAlert == .saveFailed)
    }

    @Test("An identical event never stacks behind itself")
    func identicalEventsDoNotStack() {
        let errors = ErrorManager()
        errors.report(.saveFailed)
        errors.report(.saveFailed)
        errors.report(.saveFailed)
        #expect(errors.currentAlert == .saveFailed)
        #expect(errors.pendingAlerts.isEmpty)
    }

    @Test("Different alerts wait their turn")
    func differentAlertsQueue() async throws {
        let errors = ErrorManager()
        errors.report(.saveFailed)
        errors.report(.sleepSessionUpdateFailed)
        #expect(errors.currentAlert == .saveFailed)
        #expect(errors.pendingAlerts == [.sleepSessionUpdateFailed])

        errors.dismissAlert()
        try await AlarmTestSupport.waitUntil("the second alert") { errors.currentAlert == .sleepSessionUpdateFailed }
        #expect(errors.pendingAlerts.isEmpty)
    }

    @Test("Alerts wait while the alarm screen is up, then show")
    func alertsAreHeldForTheAlarm() {
        let errors = ErrorManager()
        errors.report(.saveFailed)
        errors.holdAlerts()
        #expect(errors.currentAlert == nil, "An alert on screen would stop the alarm's cover from presenting")

        errors.report(.storageSpaceLow)
        #expect(errors.currentAlert == nil)

        errors.releaseAlerts()
        #expect(errors.currentAlert == .saveFailed)
        #expect(errors.pendingAlerts == [.storageSpaceLow])
    }

    @Test("A report from a background thread reaches the presenter on the main thread")
    func backgroundReportsReachTheMainThread() async throws {
        let errors = ErrorManager()
        DispatchQueue.global().async {
            errors.report(.saveFailed)
        }
        try await AlarmTestSupport.waitUntil("the alert from a background report") { errors.currentAlert == .saveFailed }
    }

    @Test("Only the microphone alert offers Open Settings")
    func onlyPermissionAlertsOpenSettings() {
        for error in Self.alerted {
            #expect(error.opensSettings == (error == .microphonePermissionDenied), "\(error.code)")
        }
    }
}
