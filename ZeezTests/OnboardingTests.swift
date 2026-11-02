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

// MARK: - The nights the clocks change

/// Bedtime and the goal's duration are times on the clock (found 2026-11-01, the night US
/// clocks went back). Both used to be elapsed time: onboarding that night stored a midnight
/// bedtime for an 8-hour goal and a 7:00 AM wake, and Settings read an 11 PM–7 AM goal set that
/// night as 9 hours. Fixed dates and a fixed time zone, so these run the same on any day.
@Suite("Sleep goal across a clock change")
@MainActor
struct SleepGoalClockChangeTests {

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    private static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private static func clock(_ date: Date) -> (hour: Int?, minute: Int?, day: Int?) {
        let components = calendar.dateComponents([.hour, .minute, .day], from: date)
        return (components.hour, components.minute, components.day)
    }

    @Test("When the clocks go back, 8 hours before a 7 AM wake is 11 PM the evening before")
    func bedtimeWhenClocksGoBack() {
        let bedtime = OnboardingManager.computeBedtime(wakeTime: Self.date(2026, 11, 1, 7), sleepHours: 8,
                                                       calendar: Self.calendar)
        let clock = Self.clock(bedtime)
        #expect(clock.hour == 23, "Elapsed time gives midnight")
        #expect(clock.minute == 0)
        #expect(clock.day == 31)
    }

    @Test("When the clocks go forward, 7.5 hours before a 7 AM wake is 11:30 PM")
    func bedtimeWhenClocksGoForward() {
        let bedtime = OnboardingManager.computeBedtime(wakeTime: Self.date(2026, 3, 8, 7), sleepHours: 7.5,
                                                       calendar: Self.calendar)
        let clock = Self.clock(bedtime)
        #expect(clock.hour == 23, "Elapsed time gives 10:30 PM")
        #expect(clock.minute == 30)
        #expect(clock.day == 7)
    }

    @Test("A goal of 11 PM to 7 AM is 8 hours on either night the clocks change")
    func durationAcrossClockChanges() {
        let fallBack = SleepGoalPolicy.duration(from: Self.date(2026, 10, 31, 23), to: Self.date(2026, 11, 1, 7),
                                                calendar: Self.calendar)
        let springForward = SleepGoalPolicy.duration(from: Self.date(2026, 3, 7, 23), to: Self.date(2026, 3, 8, 7),
                                                     calendar: Self.calendar)
        #expect(fallBack == 8 * 3600, "Elapsed time gives 9 hours")
        #expect(springForward == 8 * 3600, "Elapsed time gives 7 hours")
    }

    @Test("A goal's duration ignores which days its two stored times were set on")
    func durationIgnoresTheStoredDays() {
        // Settings' pickers keep each value's original date, so the two can be months apart.
        let duration = SleepGoalPolicy.duration(from: Self.date(2026, 7, 1, 22, 30), to: Self.date(2026, 11, 15, 6, 45),
                                                calendar: Self.calendar)
        #expect(duration == 8.25 * 3600)
    }

    @Test("Onboarding's bedtime and its duration agree on a clock-change night")
    func bedtimeAndDurationAgree() {
        let wake = Self.date(2026, 11, 1, 7)
        let bedtime = OnboardingManager.computeBedtime(wakeTime: wake, sleepHours: 8, calendar: Self.calendar)
        #expect(SleepGoalPolicy.duration(from: bedtime, to: wake, calendar: Self.calendar) == 8 * 3600)
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

        // viewContext is main-queue-confined; keep all access on its queue (2.4).
        try context.performAndWait {
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

            let interval = SleepGoalPolicy.duration(from: bedtime, to: wakeTime)
            #expect(abs(interval - targetHours * 3600) < 1,
                    "Persisted bedtime should be exactly 7.5 hours before wake on the clock")

            let c = Calendar.current.dateComponents([.hour, .minute], from: bedtime)
            #expect(c.hour == 23, "Bedtime hour should be 23 (11 PM)")
            #expect(c.minute == 30, "Bedtime minute should be 30")
        }
    }

    @Test("targetBedtime is exactly targetSleepDuration seconds before targetWakeTime")
    func bedtimeMatchesDuration() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext

        // viewContext is main-queue-confined; keep all access on its queue (2.4).
        try context.performAndWait {
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

            #expect(abs(SleepGoalPolicy.duration(from: bedtime, to: wakeTime) - storedDuration) < 1,
                    "Gap between bedtime and wake on the clock must equal targetSleepDuration")
        }
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
