import Foundation
import CoreData

/// Immutable, thread-safe copy of the alarm fields the scheduling stack needs.
///
/// Core Data objects must only be touched on their context's queue. The alarm
/// scheduler and the UNUserNotificationCenter delegate callbacks both run off
/// that queue, so they operate on snapshots: the snapshot is taken inside
/// `context.perform`, and everything downstream (scheduling queues,
/// notification-center callbacks) is Core-Data-free.
struct AlarmSnapshot {
    let id: UUID
    let name: String?
    let enabled: Bool
    let time: Date?
    let selectedDays: Set<Int>
    let smartWakeEnabled: Bool
    let smartWakeWindow: Int16
    let alarmSound: String?
    let vibrationOnly: Bool
    let watchHaptics: Bool
    let heavySleeperMode: Bool
    let snoozeDurationMinutes: Int

    var idString: String { id.uuidString }

    /// Must be called on `alarm`'s context queue (inside `perform`/`performAndWait`,
    /// or on the main thread for view-context objects).
    init?(_ alarm: AlarmConfiguration) {
        guard let id = alarm.id else { return nil }
        self.id = id
        self.name = alarm.name
        self.enabled = alarm.enabled
        self.time = alarm.time
        if let daysData = alarm.daysOfWeek,
           let days = try? JSONDecoder().decode(Set<Int>.self, from: daysData) {
            self.selectedDays = days
        } else {
            self.selectedDays = []
        }
        self.smartWakeEnabled = alarm.smartWakeEnabled
        self.smartWakeWindow = alarm.smartWakeWindow
        self.alarmSound = alarm.alarmSound
        self.vibrationOnly = alarm.vibrationOnly
        self.watchHaptics = alarm.watchHaptics
        self.heavySleeperMode = alarm.heavySleeperMode
        self.snoozeDurationMinutes = alarm.snoozeDurationMinutes
    }

    /// The next absolute Date this alarm's MAIN alert fires: the earliest
    /// upcoming occurrence of the alarm's hour:minute on any selected weekday
    /// (1 = Sunday … 7 = Saturday). Nil when the alarm has no time or days.
    func nextFireDate(after referenceDate: Date = Date(), calendar: Calendar = .current) -> Date? {
        guard let time = time, !selectedDays.isEmpty else { return nil }

        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        var earliest: Date?
        for weekday in selectedDays {
            var match = DateComponents()
            match.hour = timeComponents.hour
            match.minute = timeComponents.minute
            match.weekday = weekday
            if let candidate = calendar.nextDate(after: referenceDate, matching: match,
                                                 matchingPolicy: .nextTime) {
                if earliest == nil || candidate < earliest! {
                    earliest = candidate
                }
            }
        }
        return earliest
    }

    /// Looks up an alarm by its UUID string on a background context and delivers
    /// a snapshot. The completion runs on the background context's queue —
    /// callers needing the main thread must hop themselves.
    static func fetch(idString: String,
                      container: NSPersistentContainer = PersistenceController.shared.container,
                      completion: @escaping (AlarmSnapshot?) -> Void) {
        guard let uuid = UUID(uuidString: idString) else {
            completion(nil)
            return
        }
        let context = container.newBackgroundContext()
        context.perform {
            let request: NSFetchRequest<AlarmConfiguration> = AlarmConfiguration.fetchRequest()
            // "id" is a UUID attribute; SQLite stores cannot evaluate uuidString keypaths
            request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
            request.fetchLimit = 1
            let alarm = (try? context.fetch(request))?.first
            completion(alarm.flatMap(AlarmSnapshot.init))
        }
    }
}
