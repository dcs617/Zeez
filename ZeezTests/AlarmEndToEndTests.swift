import Testing
import Foundation
import UserNotifications
import CoreData
@testable import Zeez

struct AlarmEndToEndTests {
    
    // MARK: - Test Setup Helper
    
    private func createTestAlarm(
        context: NSManagedObjectContext,
        name: String = "Test Alarm",
        time: Date = Date().addingTimeInterval(300), // 5 minutes from now
        daysOfWeek: Set<Int> = [Calendar.current.component(.weekday, from: Date())],
        enabled: Bool = true,
        smartWakeEnabled: Bool = false,
        smartWakeWindow: Int16 = 30
    ) throws -> AlarmConfiguration {
        let alarm = AlarmConfiguration(context: context)
        alarm.id = UUID()
        alarm.name = name
        alarm.time = time
        alarm.enabled = enabled
        alarm.smartWakeEnabled = smartWakeEnabled
        alarm.smartWakeWindow = smartWakeWindow
        alarm.snoozeEnabled = true
        alarm.snoozeDuration = 9
        alarm.vibrationOnly = false
        alarm.watchHaptics = false
        alarm.createdAt = Date()
        alarm.modifiedAt = Date()
        
        // Encode days of week
        let daysData = try JSONEncoder().encode(daysOfWeek)
        alarm.daysOfWeek = daysData
        
        try context.save()
        return alarm
    }
    
    private func waitForAsyncOperation(timeout: TimeInterval = 5.0) async throws {
        try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
    }
    
    // MARK: - Basic Alarm Creation and Scheduling Tests
    
    @Test func createBasicAlarm() async throws {
        let controller = PersistenceController.shared
        let context = controller.container.viewContext
        let scheduler = AlarmScheduler.shared
        
        // Create a basic alarm
        let testTime = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
        let alarm = try createTestAlarm(context: context, time: testTime)
        
        // Schedule the alarm
        scheduler.scheduleSpecificAlarm(alarm)
        
        // Wait for scheduling to complete
        try await waitForAsyncOperation(timeout: 2.0)
        
        // Verify alarm was scheduled
        let expectation = SchedulingVerification()
        await expectation.verifyAlarmScheduled(for: alarm)
        let isScheduled = await expectation.isVerified
        
        #expect(isScheduled, "Basic alarm should be scheduled successfully")
    }
    
    @Test func createMultipleDayAlarm() async throws {
        let controller = PersistenceController.shared
        let context = controller.container.viewContext
        let scheduler = AlarmScheduler.shared
        
        // Create alarm for weekdays (Monday-Friday)
        let weekdays: Set<Int> = [2, 3, 4, 5, 6] // Sunday=1, Monday=2, etc.
        let testTime = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let alarm = try createTestAlarm(
            context: context,
            name: "Weekday Alarm",
            time: testTime,
            daysOfWeek: weekdays
        )
        
        // Schedule the alarm
        scheduler.scheduleSpecificAlarm(alarm)
        
        // Wait for scheduling to complete
        try await waitForAsyncOperation(timeout: 3.0)
        
        // Verify multiple notifications were scheduled
        let expectation = SchedulingVerification()
        await expectation.verifyMultipleDayAlarm(for: alarm, expectedDays: weekdays)
        let isScheduled = await expectation.isVerified
        
        #expect(isScheduled, "Multi-day alarm should schedule notifications for all selected days")
    }
    
    @Test func createSmartWakeAlarm() async throws {
        let controller = PersistenceController.shared
        let context = controller.container.viewContext
        let scheduler = AlarmScheduler.shared
        
        // Create smart wake alarm
        let testTime = Calendar.current.date(byAdding: .hour, value: 2, to: Date())!
        let alarm = try createTestAlarm(
            context: context,
            name: "Smart Wake Alarm",
            time: testTime,
            smartWakeEnabled: true,
            smartWakeWindow: 30
        )
        
        // Schedule the alarm
        scheduler.scheduleSpecificAlarm(alarm)
        
        // Wait for scheduling to complete
        try await waitForAsyncOperation(timeout: 2.0)
        
        // Verify both smart wake and backup notifications were scheduled
        let expectation = SchedulingVerification()
        await expectation.verifySmartWakeAlarm(for: alarm)
        let isScheduled = await expectation.isVerified
        
        #expect(isScheduled, "Smart wake alarm should schedule both early and standard notifications")
    }
    
    // MARK: - Alarm Modification Tests
    
    @Test func editAlarmTime() async throws {
        let controller = PersistenceController.shared
        let context = controller.container.viewContext
        let scheduler = AlarmScheduler.shared
        
        // Create initial alarm
        let initialTime = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let alarm = try createTestAlarm(context: context, time: initialTime)
        
        // Schedule initial alarm
        scheduler.scheduleSpecificAlarm(alarm)
        try await waitForAsyncOperation(timeout: 2.0)
        
        // Modify the alarm time
        let newTime = Calendar.current.date(byAdding: .hour, value: 2, to: Date())!
        alarm.time = newTime
        alarm.modifiedAt = Date()
        try context.save()
        
        // Reschedule the modified alarm
        scheduler.scheduleSpecificAlarm(alarm)
        try await waitForAsyncOperation(timeout: 2.0)
        
        // Verify new time is scheduled and old time is removed
        let expectation = SchedulingVerification()
        await expectation.verifyAlarmTimeUpdated(for: alarm, newTime: newTime)
        let isUpdated = await expectation.isVerified
        
        #expect(isUpdated, "Alarm time modification should update scheduled notifications")
    }
    
    @Test func toggleAlarmEnabled() async throws {
        let controller = PersistenceController.shared
        let context = controller.container.viewContext
        let scheduler = AlarmScheduler.shared
        
        // Create enabled alarm
        let alarm = try createTestAlarm(context: context, enabled: true)
        scheduler.scheduleSpecificAlarm(alarm)
        try await waitForAsyncOperation(timeout: 2.0)
        
        // Disable the alarm
        alarm.enabled = false
        alarm.modifiedAt = Date()
        try context.save()
        
        scheduler.scheduleSpecificAlarm(alarm)
        try await waitForAsyncOperation(timeout: 2.0)
        
        // Verify notifications were removed
        let expectation = SchedulingVerification()
        await expectation.verifyAlarmDisabled(for: alarm)
        let isDisabled = await expectation.isVerified
        
        #expect(isDisabled, "Disabling alarm should remove scheduled notifications")
        
        // Re-enable the alarm
        alarm.enabled = true
        alarm.modifiedAt = Date()
        try context.save()
        
        scheduler.scheduleSpecificAlarm(alarm)
        try await waitForAsyncOperation(timeout: 2.0)
        
        // Verify notifications were restored
        await expectation.verifyAlarmEnabled(for: alarm)
        let isReEnabled = await expectation.isVerified
        
        #expect(isReEnabled, "Re-enabling alarm should restore scheduled notifications")
    }
    
    // MARK: - Alarm Deletion Tests
    
    @Test func deleteAlarm() async throws {
        let controller = PersistenceController.shared
        let context = controller.container.viewContext
        let scheduler = AlarmScheduler.shared
        
        // Create and schedule alarm
        let alarm = try createTestAlarm(context: context)
        let alarmID = alarm.id!
        
        scheduler.scheduleSpecificAlarm(alarm)
        try await waitForAsyncOperation(timeout: 2.0)
        
        // Delete the alarm
        context.delete(alarm)
        try context.save()
        
        // Schedule all alarms (should remove deleted alarm's notifications)
        scheduler.scheduleAllAlarms(context: context)
        try await waitForAsyncOperation(timeout: 3.0)
        
        // Verify notifications were removed
        let expectation = SchedulingVerification()
        await expectation.verifyAlarmDeleted(alarmID: alarmID)
        let isDeleted = await expectation.isVerified
        
        #expect(isDeleted, "Deleting alarm should remove all its notifications")
    }
    
    // MARK: - Notification Permission Tests
    
    @Test func checkNotificationPermissions() async throws {
        let scheduler = AlarmScheduler.shared
        
        let expectation = PermissionVerification()
        scheduler.checkNotificationPermissions { status in
            Task {
                await expectation.setPermissionStatus(status)
            }
        }
        
        // Wait for permission check
        try await waitForAsyncOperation(timeout: 3.0)
        
        let status = await expectation.permissionStatus
        #expect(status != .denied, "Notification permissions should not be denied for alarm functionality")
    }
    
    @Test func scheduleTestNotification() async throws {
        let scheduler = AlarmScheduler.shared
        
        // Schedule test notification
        scheduler.scheduleTestNotification()
        
        // Wait for scheduling
        try await waitForAsyncOperation(timeout: 1.0)
        
        // Verify test notification was scheduled
        let expectation = SchedulingVerification()
        await expectation.verifyTestNotificationScheduled()
        let isScheduled = await expectation.isVerified
        
        #expect(isScheduled, "Test notification should be scheduled successfully")
    }
    
    // MARK: - Stress Testing
    
    @Test func multipleAlarmsScheduling() async throws {
        let controller = PersistenceController.shared
        let context = controller.container.viewContext
        let scheduler = AlarmScheduler.shared
        
        // Create multiple alarms
        var alarms: [AlarmConfiguration] = []
        for i in 0..<10 {
            let time = Calendar.current.date(byAdding: .hour, value: i + 1, to: Date())!
            let days: Set<Int> = Set([((i % 7) + 1)]) // Distribute across different days
            let alarm = try createTestAlarm(
                context: context,
                name: "Stress Test Alarm \(i)",
                time: time,
                daysOfWeek: days
            )
            alarms.append(alarm)
        }
        
        // Schedule all alarms
        scheduler.scheduleAllAlarms(context: context)
        try await waitForAsyncOperation(timeout: 5.0)
        
        // Verify all alarms were scheduled
        let expectation = SchedulingVerification()
        await expectation.verifyMultipleAlarmsScheduled(alarms: alarms)
        let allScheduled = await expectation.isVerified
        
        #expect(allScheduled, "Multiple alarms should all be scheduled successfully")
    }
    
    @Test func rapidAlarmModifications() async throws {
        let controller = PersistenceController.shared
        let context = controller.container.viewContext
        let scheduler = AlarmScheduler.shared
        
        // Create initial alarm
        let alarm = try createTestAlarm(context: context)
        scheduler.scheduleSpecificAlarm(alarm)
        try await waitForAsyncOperation(timeout: 1.0)
        
        // Make rapid modifications
        for i in 1...5 {
            alarm.time = Calendar.current.date(byAdding: .minute, value: i * 10, to: Date())
            alarm.modifiedAt = Date()
            try context.save()
            
            scheduler.scheduleSpecificAlarm(alarm)
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second between changes
        }
        
        // Wait for all operations to complete
        try await waitForAsyncOperation(timeout: 3.0)
        
        // Verify final state is correct
        let expectation = SchedulingVerification()
        await expectation.verifyAlarmScheduled(for: alarm)
        let isFinalStateCorrect = await expectation.isVerified
        
        #expect(isFinalStateCorrect, "Rapid alarm modifications should result in correct final state")
    }
    
    // MARK: - Integration Tests
    
    @Test func alarmObserverIntegration() async throws {
        let controller = PersistenceController.shared
        let context = controller.container.viewContext
        let observer = AlarmObserver.shared
        
        // Reset observer state
        observer.reset()
        
        // Start observing
        observer.startObserving(context: context)
        
        // Create alarm (should trigger observer)
        let alarm = try createTestAlarm(context: context)
        
        // Wait for observer to process changes
        try await waitForAsyncOperation(timeout: 3.0)
        
        // Verify alarm was scheduled through observer
        let expectation = SchedulingVerification()
        await expectation.verifyAlarmScheduled(for: alarm)
        let isScheduledByObserver = await expectation.isVerified
        
        #expect(isScheduledByObserver, "AlarmObserver should automatically schedule new alarms")
    }
}

// MARK: - Test Helper Actors

private actor SchedulingVerification {
    private(set) var isVerified = false
    
    func verifyAlarmScheduled(for alarm: AlarmConfiguration) {
        let notificationCenter = UNUserNotificationCenter.current()
        guard let alarmID = alarm.id?.uuidString else {
            isVerified = false
            return
        }
        
        notificationCenter.getPendingNotificationRequests { [weak self] requests in
            let alarmRequests = requests.filter { $0.identifier.hasPrefix(alarmID) }
            Task {
                await self?.setVerified(!alarmRequests.isEmpty)
            }
        }
    }
    
    func verifyMultipleDayAlarm(for alarm: AlarmConfiguration, expectedDays: Set<Int>) {
        let notificationCenter = UNUserNotificationCenter.current()
        guard let alarmID = alarm.id?.uuidString else {
            isVerified = false
            return
        }
        
        notificationCenter.getPendingNotificationRequests { [weak self] requests in
            let alarmRequests = requests.filter { $0.identifier.hasPrefix(alarmID) }
            // Should have at least as many notifications as days
            Task {
                await self?.setVerified(alarmRequests.count >= expectedDays.count)
            }
        }
    }
    
    func verifySmartWakeAlarm(for alarm: AlarmConfiguration) {
        let notificationCenter = UNUserNotificationCenter.current()
        guard let alarmID = alarm.id?.uuidString else {
            isVerified = false
            return
        }
        
        notificationCenter.getPendingNotificationRequests { [weak self] requests in
            let alarmRequests = requests.filter { $0.identifier.hasPrefix(alarmID) }
            // Should have both smart wake and standard notifications
            let hasSmartWake = alarmRequests.contains { $0.identifier.contains("smart") }
            let hasStandard = alarmRequests.contains { $0.identifier.contains("standard") }
            Task {
                await self?.setVerified(hasSmartWake && hasStandard)
            }
        }
    }
    
    func verifyAlarmTimeUpdated(for alarm: AlarmConfiguration, newTime: Date) {
        let notificationCenter = UNUserNotificationCenter.current()
        guard let alarmID = alarm.id?.uuidString else {
            isVerified = false
            return
        }
        
        notificationCenter.getPendingNotificationRequests { [weak self] requests in
            let alarmRequests = requests.filter { $0.identifier.hasPrefix(alarmID) }
            
            // Check if notifications match the new time
            let calendar = Calendar.current
            let expectedHour = calendar.component(.hour, from: newTime)
            let expectedMinute = calendar.component(.minute, from: newTime)
            
            let hasCorrectTime = alarmRequests.contains { request in
                if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                    return trigger.dateComponents.hour == expectedHour &&
                           trigger.dateComponents.minute == expectedMinute
                }
                return false
            }
            
            Task {
                await self?.setVerified(hasCorrectTime)
            }
        }
    }
    
    func verifyAlarmDisabled(for alarm: AlarmConfiguration) {
        let notificationCenter = UNUserNotificationCenter.current()
        guard let alarmID = alarm.id?.uuidString else {
            isVerified = false
            return
        }
        
        notificationCenter.getPendingNotificationRequests { [weak self] requests in
            let alarmRequests = requests.filter { $0.identifier.hasPrefix(alarmID) }
            Task {
                await self?.setVerified(alarmRequests.isEmpty)
            }
        }
    }
    
    func verifyAlarmEnabled(for alarm: AlarmConfiguration) {
        verifyAlarmScheduled(for: alarm)
    }
    
    func verifyAlarmDeleted(alarmID: UUID) {
        let notificationCenter = UNUserNotificationCenter.current()
        let alarmIDString = alarmID.uuidString
        
        notificationCenter.getPendingNotificationRequests { [weak self] requests in
            let alarmRequests = requests.filter { $0.identifier.hasPrefix(alarmIDString) }
            Task {
                await self?.setVerified(alarmRequests.isEmpty)
            }
        }
    }
    
    func verifyTestNotificationScheduled() {
        let notificationCenter = UNUserNotificationCenter.current()
        
        notificationCenter.getPendingNotificationRequests { [weak self] requests in
            let testRequests = requests.filter { $0.identifier == "test-notification" }
            Task {
                await self?.setVerified(!testRequests.isEmpty)
            }
        }
    }
    
    func verifyMultipleAlarmsScheduled(alarms: [AlarmConfiguration]) {
        let notificationCenter = UNUserNotificationCenter.current()
        
        notificationCenter.getPendingNotificationRequests { [weak self] requests in
            var scheduledCount = 0
            for alarm in alarms {
                if let alarmID = alarm.id?.uuidString {
                    let alarmRequests = requests.filter { $0.identifier.hasPrefix(alarmID) }
                    if !alarmRequests.isEmpty {
                        scheduledCount += 1
                    }
                }
            }
            Task {
                await self?.setVerified(scheduledCount == alarms.count)
            }
        }
    }
    
    func setVerified(_ value: Bool) {
        isVerified = value
    }
}

private actor PermissionVerification {
    private(set) var permissionStatus: UNAuthorizationStatus = .notDetermined
    
    func setPermissionStatus(_ status: UNAuthorizationStatus) {
        permissionStatus = status
    }
}