import Testing
import CoreData
@testable import Zeez

// MARK: - Bedtime Calculation Tests

@Suite("Onboarding – Bedtime Calculation")
@MainActor
struct OnboardingBedtimeTests {

    // Regression test: Int(7.5) == 7, so Calendar.date(byAdding: .hour, value: -7) gives
    // midnight instead of 11:30 PM. OnboardingManager.computeBedtime uses TimeInterval arithmetic.
    @Test("7.5-hour goal with 7:00 AM wake produces 11:30 PM bedtime")
    func fractionalBedtime() throws {
        let wake = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date())!
        let bedtime = OnboardingManager.computeBedtime(wakeTime: wake, sleepHours: 7.5)
        let c = Calendar.current.dateComponents([.hour, .minute], from: bedtime)
        #expect(c.hour == 23, "Hour should be 23 (11 PM)")
        #expect(c.minute == 30, "Minute should be 30")
    }

    @Test("8-hour goal with 7:00 AM wake produces 11:00 PM bedtime")
    func wholeBedtime() throws {
        let wake = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date())!
        let bedtime = OnboardingManager.computeBedtime(wakeTime: wake, sleepHours: 8.0)
        let c = Calendar.current.dateComponents([.hour, .minute], from: bedtime)
        #expect(c.hour == 23)
        #expect(c.minute == 0)
    }

    @Test("Fractional formula differs from truncated formula for non-whole hours")
    func fractionalVsTruncated() {
        let wake = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date())!
        let correct = OnboardingManager.computeBedtime(wakeTime: wake, sleepHours: 7.5)
        let truncated = Calendar.current.date(byAdding: .hour, value: -Int(7.5), to: wake)!
        // These must differ — the truncated version is the bug we fixed
        #expect(correct != truncated, "Fractional and truncated bedtimes must not be equal")
    }
}

// MARK: - Bedtime Persistence Tests

@Suite("Onboarding – Bedtime Persistence")
@MainActor
struct OnboardingPersistenceTests {

    @Test("UserPreferences persists correct fractional bedtime")
    func persistsFractionalBedtime() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext

        let targetHours: Double = 7.5
        let wake = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date())!

        let prefs = UserPreferences(context: context)
        prefs.id = UUID()
        prefs.targetSleepDuration = targetHours * 3600
        prefs.targetWakeTime = wake
        prefs.targetBedtime = OnboardingManager.computeBedtime(wakeTime: wake, sleepHours: targetHours)
        prefs.sleepGoalEnabled = true
        prefs.createdAt = Date()
        prefs.modifiedAt = Date()
        try context.save()

        let fetched = try context.fetch(UserPreferences.fetchRequest())
        let saved = try #require(fetched.first)
        let bedtime = try #require(saved.targetBedtime)
        let wakeTime = try #require(saved.targetWakeTime)

        let interval = wakeTime.timeIntervalSince(bedtime)
        #expect(abs(interval - targetHours * 3600) < 1,
                "Persisted interval between wake and bedtime should be exactly 7.5 hours")

        let c = Calendar.current.dateComponents([.hour, .minute], from: bedtime)
        #expect(c.hour == 23, "Bedtime hour should be 23 (11 PM)")
        #expect(c.minute == 30, "Bedtime minute should be 30")
    }

    @Test("targetBedtime is exactly targetSleepDuration seconds before targetWakeTime")
    func bedtimeMatchesDuration() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext

        let targetHours: Double = 6.5
        let wake = Calendar.current.date(bySettingHour: 8, minute: 30, second: 0, of: Date())!

        let prefs = UserPreferences(context: context)
        prefs.id = UUID()
        prefs.targetSleepDuration = targetHours * 3600
        prefs.targetWakeTime = wake
        prefs.targetBedtime = OnboardingManager.computeBedtime(wakeTime: wake, sleepHours: targetHours)
        prefs.createdAt = Date()
        prefs.modifiedAt = Date()
        try context.save()

        let saved = try #require(try context.fetch(UserPreferences.fetchRequest()).first)
        let wakeTime = try #require(saved.targetWakeTime)
        let bedtime = try #require(saved.targetBedtime)
        let storedDuration = saved.targetSleepDuration

        #expect(abs(wakeTime.timeIntervalSince(bedtime) - storedDuration) < 1,
                "Gap between wake and bedtime must equal targetSleepDuration")
    }
}

// MARK: - HealthKit Authorization Notes
//
// OnboardingManager.requestHealthKitPermissions() calls HKHealthStore.requestAuthorization,
// which presents a system sheet that cannot be controlled in unit tests.
//
// Manual verification required:
//   1. Launch in Simulator, go through onboarding, and DENY health access on the system sheet.
//      Expected: onboarding advances past the HealthKit step without error or alert.
//      Expected: "Apple Health setup complete" label is NOT shown (healthKitSetupCompleted = false).
//      Expected: the app reaches the main dashboard normally.
//
//   2. Grant health access during onboarding.
//      Expected: "Apple Health setup complete" is shown on the HealthKit step and completion screen.
//      Expected: Settings > Sleep Data > Import works as before.
//
//   3. Test on a device/simulator where HealthKit is unavailable (e.g., iPad).
//      Expected: the HealthKit step is skipped without error; onboarding completes normally.
//
//   4. Decline health access, complete onboarding, then go to Settings > Sleep Data > Import.
//      Expected: the import flow can still trigger its own HealthKit authorization request.
//
// Notification authorization follows the same optional pattern:
//   - Denying notifications advances the flow with notificationsAuthorized = false.
//   - A system-level authorization error is logged; no "Couldn't Save Settings" alert appears.
