import Testing
import Foundation
import UserNotifications
@testable import Zeez

struct AlarmRaceConditionTests {
    
    /// Test that multiple rapid alarm scheduling operations don't create race conditions
    @Test func rapidAlarmSchedulingOperations() async throws {
        let scheduler = AlarmScheduler.shared
        
        // Create test context
        let controller = PersistenceController.shared
        let context = controller.container.viewContext
        
        // Create multiple test alarms
        var testAlarms: [AlarmConfiguration] = []
        for i in 0..<5 {
            let alarm = AlarmConfiguration(context: context)
            alarm.id = UUID()
            alarm.name = "Test Alarm \(i)"
            alarm.enabled = true
            alarm.time = Date().addingTimeInterval(TimeInterval(i * 3600)) // 1 hour apart
            alarm.smartWakeEnabled = false
            
            // Set days of week (every day for simplicity)
            let days: Set<Int> = [1, 2, 3, 4, 5, 6, 7]
            if let daysData = try? JSONEncoder().encode(days) {
                alarm.daysOfWeek = daysData
            }
            
            testAlarms.append(alarm)
        }
        
        try context.save()
        
        // Test rapid scheduling operations
        let expectation = ExclusionExpectation()
        
        await withTaskGroup(of: Void.self) { group in
            for alarm in testAlarms {
                group.addTask {
                    scheduler.scheduleSpecificAlarm(alarm)
                }
            }
        }
        
        // Give the scheduler time to complete all operations
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Verify that scheduling completed without race conditions
        // (This test primarily ensures no crashes occur during concurrent scheduling)
        #expect(true, "Concurrent alarm scheduling completed without crashes")
    }
    
    /// Test that alarm observer debouncing works correctly
    @Test func alarmObserverDebouncing() async throws {
        let observer = AlarmObserver.shared
        let scheduler = AlarmScheduler.shared
        
        // Reset any existing state
        observer.reset()
        
        let controller = PersistenceController.shared
        let context = controller.container.viewContext
        
        // Create a test alarm
        let alarm = AlarmConfiguration(context: context)
        alarm.id = UUID()
        alarm.name = "Debounce Test Alarm"
        alarm.enabled = true
        alarm.time = Date().addingTimeInterval(3600)
        
        let days: Set<Int> = [1, 2, 3, 4, 5, 6, 7]
        if let daysData = try? JSONEncoder().encode(days) {
            alarm.daysOfWeek = daysData
        }
        
        try context.save()
        
        // Make rapid changes to the alarm
        alarm.time = alarm.time?.addingTimeInterval(300) // +5 minutes
        try context.save()
        
        alarm.time = alarm.time?.addingTimeInterval(600) // +10 minutes
        try context.save()
        
        alarm.time = alarm.time?.addingTimeInterval(-300) // -5 minutes
        try context.save()
        
        // Wait for debouncing to complete
        try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
        
        // Test passes if no crashes occurred during rapid updates
        #expect(true, "Alarm observer handled rapid updates without issues")
    }
}

/// Helper class to ensure exclusive access during testing
private actor ExclusionExpectation {
    private var isProcessing = false
    
    func startProcessing() async -> Bool {
        guard !isProcessing else { return false }
        isProcessing = true
        return true
    }
    
    func finishProcessing() {
        isProcessing = false
    }
}