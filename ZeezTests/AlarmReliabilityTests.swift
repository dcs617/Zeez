import Testing
import Foundation
import UserNotifications
import CoreData
import UIKit
@testable import Zeez

struct AlarmReliabilityTests {
    
    // MARK: - Persistence Testing
    
    @Test func alarmPersistsThroughAppRestart() async throws {
        let controller = PersistenceController.shared
        let context = controller.container.viewContext
        let scheduler = AlarmScheduler.shared
        
        // Create and schedule alarm
        let testTime = Calendar.current.date(byAdding: .hour, value: 2, to: Date())!
        let alarm = AlarmConfiguration(context: context)
        alarm.id = UUID()
        alarm.name = "Persistence Test Alarm"
        alarm.time = testTime
        alarm.enabled = true
        
        let days: Set<Int> = [Calendar.current.component(.weekday, from: Date())]
        let daysData = try JSONEncoder().encode(days)
        alarm.daysOfWeek = daysData
        
        try context.save()
        
        // Schedule the alarm
        scheduler.scheduleSpecificAlarm(alarm)
        try await Task.sleep(nanoseconds: 2_000_000_000) // Wait 2 seconds
        
        // Simulate app restart by reinitializing scheduler
        let newScheduler = AlarmScheduler.shared
        newScheduler.scheduleAllAlarms(context: context)
        try await Task.sleep(nanoseconds: 3_000_000_000) // Wait 3 seconds
        
        // Verify alarm is still scheduled
        let expectation = ReliabilityVerification()
        await expectation.verifyAlarmPersistence(alarmID: alarm.id!)
        let isPersistent = await expectation.isVerified
        
        #expect(isPersistent, "Alarm should persist through app restart simulation")
    }
    
    @Test func alarmSurvivesSystemTimeChange() async throws {
        let controller = PersistenceController.shared
        let context = controller.container.viewContext
        let scheduler = AlarmScheduler.shared
        
        // Create alarm for future time
        let futureTime = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let alarm = AlarmConfiguration(context: context)
        alarm.id = UUID()
        alarm.name = "Time Change Test Alarm"
        alarm.time = futureTime
        alarm.enabled = true
        
        let days: Set<Int> = [Calendar.current.component(.weekday, from: futureTime)]
        let daysData = try JSONEncoder().encode(days)
        alarm.daysOfWeek = daysData
        
        try context.save()
        
        // Schedule the alarm
        scheduler.scheduleSpecificAlarm(alarm)
        try await Task.sleep(nanoseconds: 2_000_000_000)
        
        // Simulate significant time change by rescheduling all alarms
        // (This is what happens when iOS detects time change)
        scheduler.scheduleAllAlarms(context: context)
        try await Task.sleep(nanoseconds: 3_000_000_000)
        
        // Verify alarm is still properly scheduled
        let expectation = ReliabilityVerification()
        await expectation.verifyAlarmScheduledCorrectly(for: alarm)
        let survives = await expectation.isVerified
        
        #expect(survives, "Alarm should survive system time changes")
    }
    
    // MARK: - Stress Testing
    
    @Test func createDeleteManyAlarmsRapidly() async throws {
        let controller = PersistenceController.shared
        let context = controller.container.viewContext
        let scheduler = AlarmScheduler.shared
        
        var createdAlarms: [AlarmConfiguration] = []
        
        // Create 20 alarms rapidly
        for i in 0..<20 {
            let alarm = AlarmConfiguration(context: context)
            alarm.id = UUID()
            alarm.name = "Stress Test Alarm \(i)"
            alarm.time = Calendar.current.date(byAdding: .minute, value: i * 5, to: Date())
            alarm.enabled = true
            
            let days: Set<Int> = [((i % 7) + 1)]
            let daysData = try JSONEncoder().encode(days)
            alarm.daysOfWeek = daysData
            
            createdAlarms.append(alarm)
        }
        
        try context.save()
        
        // Schedule all alarms
        scheduler.scheduleAllAlarms(context: context)
        try await Task.sleep(nanoseconds: 5_000_000_000) // Wait 5 seconds
        
        // Verify all were scheduled
        let expectation = ReliabilityVerification()
        await expectation.verifyMultipleAlarmsExist(count: 20)
        let allScheduled = await expectation.isVerified
        
        #expect(allScheduled, "Should handle creating many alarms rapidly")
        
        // Now delete them all rapidly
        for alarm in createdAlarms {
            context.delete(alarm)
        }
        try context.save()
        
        // Reschedule (should remove all deleted alarms)
        scheduler.scheduleAllAlarms(context: context)
        try await Task.sleep(nanoseconds: 3_000_000_000)
        
        // Verify all were removed
        await expectation.verifyNoAlarmsRemain(alarmIDs: createdAlarms.compactMap { $0.id })
        let allDeleted = await expectation.isVerified
        
        #expect(allDeleted, "Should handle deleting many alarms rapidly")
    }
    
    @Test func modifyAlarmWhileScheduling() async throws {
        let controller = PersistenceController.shared
        let context = controller.container.viewContext
        let scheduler = AlarmScheduler.shared
        
        // Create alarm
        let alarm = AlarmConfiguration(context: context)
        alarm.id = UUID()
        alarm.name = "Concurrent Modification Test"
        alarm.time = Calendar.current.date(byAdding: .hour, value: 1, to: Date())
        alarm.enabled = true
        
        let days: Set<Int> = [Calendar.current.component(.weekday, from: Date())]
        let daysData = try JSONEncoder().encode(days)
        alarm.daysOfWeek = daysData
        
        try context.save()
        
        // Start scheduling in background
        Task {
            scheduler.scheduleSpecificAlarm(alarm)
        }
        
        // Immediately modify the alarm while scheduling
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        alarm.time = Calendar.current.date(byAdding: .hour, value: 2, to: Date())
        alarm.modifiedAt = Date()
        try context.save()
        
        // Schedule the modified alarm
        scheduler.scheduleSpecificAlarm(alarm)
        
        // Wait for operations to complete
        try await Task.sleep(nanoseconds: 3_000_000_000)
        
        // Verify final state is consistent
        let expectation = ReliabilityVerification()
        await expectation.verifyAlarmScheduledCorrectly(for: alarm)
        let isConsistent = await expectation.isVerified
        
        #expect(isConsistent, "Should handle concurrent alarm modifications safely")
    }
    
    // MARK: - Edge Case Testing
    
    @Test func alarmScheduledForCurrentTime() async throws {
        let controller = PersistenceController.shared
        let context = controller.container.viewContext
        let scheduler = AlarmScheduler.shared
        
        // Create alarm for current time (edge case)
        let currentTime = Date()
        let alarm = AlarmConfiguration(context: context)
        alarm.id = UUID()
        alarm.name = "Current Time Alarm"
        alarm.time = currentTime
        alarm.enabled = true
        
        let days: Set<Int> = [Calendar.current.component(.weekday, from: currentTime)]
        let daysData = try JSONEncoder().encode(days)
        alarm.daysOfWeek = daysData
        
        try context.save()
        
        // Schedule the alarm
        scheduler.scheduleSpecificAlarm(alarm)
        try await Task.sleep(nanoseconds: 2_000_000_000)
        
        // Verify alarm is scheduled (should schedule for next week since time has passed)
        let expectation = ReliabilityVerification()
        await expectation.verifyAlarmExists(alarmID: alarm.id!)
        let isScheduled = await expectation.isVerified
        
        #expect(isScheduled, "Should handle scheduling alarm for current/past time")
    }
    
    @Test func alarmWithInvalidDaysOfWeek() async throws {
        let controller = PersistenceController.shared
        let context = controller.container.viewContext
        let scheduler = AlarmScheduler.shared
        
        // Create alarm with empty days of week
        let alarm = AlarmConfiguration(context: context)
        alarm.id = UUID()
        alarm.name = "Invalid Days Alarm"
        alarm.time = Calendar.current.date(byAdding: .hour, value: 1, to: Date())
        alarm.enabled = true
        
        let emptyDays: Set<Int> = []
        let daysData = try JSONEncoder().encode(emptyDays)
        alarm.daysOfWeek = daysData
        
        try context.save()
        
        // Attempt to schedule the alarm (should handle gracefully)
        scheduler.scheduleSpecificAlarm(alarm)
        try await Task.sleep(nanoseconds: 2_000_000_000)
        
        // Verify no crash occurred and alarm is not scheduled
        let expectation = ReliabilityVerification()
        await expectation.verifyAlarmNotScheduled(alarmID: alarm.id!)
        let handledGracefully = await expectation.isVerified
        
        #expect(handledGracefully, "Should handle alarm with invalid days of week gracefully")
    }
    
    @Test func alarmWithNilTime() async throws {
        let controller = PersistenceController.shared
        let context = controller.container.viewContext
        let scheduler = AlarmScheduler.shared
        
        // Create alarm with nil time
        let alarm = AlarmConfiguration(context: context)
        alarm.id = UUID()
        alarm.name = "Nil Time Alarm"
        alarm.time = nil
        alarm.enabled = true
        
        let days: Set<Int> = [Calendar.current.component(.weekday, from: Date())]
        let daysData = try JSONEncoder().encode(days)
        alarm.daysOfWeek = daysData
        
        try context.save()
        
        // Attempt to schedule the alarm (should handle gracefully)
        scheduler.scheduleSpecificAlarm(alarm)
        try await Task.sleep(nanoseconds: 2_000_000_000)
        
        // Verify no crash occurred and alarm is not scheduled
        let expectation = ReliabilityVerification()
        await expectation.verifyAlarmNotScheduled(alarmID: alarm.id!)
        let handledGracefully = await expectation.isVerified
        
        #expect(handledGracefully, "Should handle alarm with nil time gracefully")
    }
    
    // MARK: - Memory Pressure Testing
    
    @Test func scheduleAlarmsUnderMemoryPressure() async throws {
        let controller = PersistenceController.shared
        let context = controller.container.viewContext
        let scheduler = AlarmScheduler.shared
        
        // Create many alarms to simulate memory pressure
        var alarms: [AlarmConfiguration] = []
        for i in 0..<50 {
            let alarm = AlarmConfiguration(context: context)
            alarm.id = UUID()
            alarm.name = "Memory Pressure Alarm \(i)"
            alarm.time = Calendar.current.date(byAdding: .minute, value: i * 2, to: Date())
            alarm.enabled = true
            
            let days: Set<Int> = [((i % 7) + 1)]
            let daysData = try JSONEncoder().encode(days)
            alarm.daysOfWeek = daysData
            
            alarms.append(alarm)
        }
        
        try context.save()
        
        // Simulate memory pressure by posting notification
        NotificationCenter.default.post(
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        // Schedule all alarms under memory pressure
        scheduler.scheduleAllAlarms(context: context)
        try await Task.sleep(nanoseconds: 8_000_000_000) // Wait 8 seconds
        
        // Verify at least some alarms were scheduled (memory pressure shouldn't prevent all)
        let expectation = ReliabilityVerification()
        await expectation.verifyMultipleAlarmsExist(count: 25) // At least half
        let survivedMemoryPressure = await expectation.isVerified
        
        #expect(survivedMemoryPressure, "Should handle alarm scheduling under memory pressure")
    }
    
    // MARK: - Long Running Tests
    
    @Test func alarmSchedulingOverTime() async throws {
        let controller = PersistenceController.shared
        let context = controller.container.viewContext
        let scheduler = AlarmScheduler.shared
        
        // Create alarm
        let alarm = AlarmConfiguration(context: context)
        alarm.id = UUID()
        alarm.name = "Long Running Test Alarm"
        alarm.time = Calendar.current.date(byAdding: .hour, value: 1, to: Date())
        alarm.enabled = true
        
        let days: Set<Int> = [Calendar.current.component(.weekday, from: Date())]
        let daysData = try JSONEncoder().encode(days)
        alarm.daysOfWeek = daysData
        
        try context.save()
        
        // Schedule and verify multiple times over a period
        for iteration in 1...5 {
            scheduler.scheduleSpecificAlarm(alarm)
            try await Task.sleep(nanoseconds: 2_000_000_000)
            
            // Verify scheduling is still working
            let expectation = ReliabilityVerification()
            await expectation.verifyAlarmScheduledCorrectly(for: alarm)
            let isWorking = await expectation.isVerified
            
            #expect(isWorking, "Alarm scheduling should work consistently over time (iteration \(iteration))")
        }
    }
}

// MARK: - Reliability Test Helper Actor

private actor ReliabilityVerification {
    private(set) var isVerified = false
    
    func verifyAlarmPersistence(alarmID: UUID) {
        let notificationCenter = UNUserNotificationCenter.current()
        let alarmIDString = alarmID.uuidString
        
        notificationCenter.getPendingNotificationRequests { [weak self] requests in
            let alarmRequests = requests.filter { $0.identifier.hasPrefix(alarmIDString) }
            Task {
                await self?.setVerified(!alarmRequests.isEmpty)
            }
        }
    }
    
    func verifyAlarmScheduledCorrectly(for alarm: AlarmConfiguration) {
        guard let alarmID = alarm.id?.uuidString,
              let alarmTime = alarm.time else {
            isVerified = false
            return
        }
        
        let notificationCenter = UNUserNotificationCenter.current()
        
        notificationCenter.getPendingNotificationRequests { [weak self] requests in
            let alarmRequests = requests.filter { $0.identifier.hasPrefix(alarmID) }
            
            if alarmRequests.isEmpty {
                Task {
                    await self?.setVerified(false)
                }
                return
            }
            
            // Verify at least one notification has the correct time
            let calendar = Calendar.current
            let expectedHour = calendar.component(.hour, from: alarmTime)
            let expectedMinute = calendar.component(.minute, from: alarmTime)
            
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
    
    func verifyMultipleAlarmsExist(count: Int) {
        let notificationCenter = UNUserNotificationCenter.current()
        
        notificationCenter.getPendingNotificationRequests { [weak self] requests in
            Task {
                await self?.setVerified(requests.count >= count)
            }
        }
    }
    
    func verifyNoAlarmsRemain(alarmIDs: [UUID]) {
        let notificationCenter = UNUserNotificationCenter.current()
        let alarmIDStrings = alarmIDs.map { $0.uuidString }
        
        notificationCenter.getPendingNotificationRequests { [weak self] requests in
            let remainingAlarmRequests = requests.filter { request in
                alarmIDStrings.contains { alarmID in
                    request.identifier.hasPrefix(alarmID)
                }
            }
            
            Task {
                await self?.setVerified(remainingAlarmRequests.isEmpty)
            }
        }
    }
    
    func verifyAlarmExists(alarmID: UUID) {
        verifyAlarmPersistence(alarmID: alarmID)
    }
    
    func verifyAlarmNotScheduled(alarmID: UUID) {
        let notificationCenter = UNUserNotificationCenter.current()
        let alarmIDString = alarmID.uuidString
        
        notificationCenter.getPendingNotificationRequests { [weak self] requests in
            let alarmRequests = requests.filter { $0.identifier.hasPrefix(alarmIDString) }
            Task {
                await self?.setVerified(alarmRequests.isEmpty)
            }
        }
    }
    
    func setVerified(_ value: Bool) {
        isVerified = value
    }
}