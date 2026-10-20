import Foundation
import CoreData
import os.log

/// Builds the plain-value payloads the phone sends to the watch.
///
/// Extracted from `WatchConnectivityHandler` (second-audit D2a) so the Core Data path,
/// rewritten by A2/A5 with no tests, can run against an in-memory store. Only value types
/// leave the context's queue, per the alarm-stack snapshot pattern.
enum WatchPayloadBuilder {

    /// The alarm that rings next, as the watch should show it.
    ///
    /// `AlarmConfiguration.time` only carries an hour and minute; its date part is whenever the
    /// alarm was created or edited. Sorting on it chose the oldest-dated alarm rather than the
    /// next to ring, and sending it as-is put a past date on the wire, which hid the watch's
    /// "in 7h 12m" countdown. This sends the absolute next main fire instead.
    ///
    /// With no enabled alarm that can ring, the status is explicitly disabled, so the watch
    /// clears a stale "Next Alarm" rather than keeping the last one it was told about.
    static func nextAlarmStatus(from snapshots: [AlarmSnapshot], now: Date = Date(),
                                calendar: Calendar = .current) -> WatchAlarmStatus {
        let upcoming = snapshots
            .filter(\.enabled)
            .compactMap { snapshot in
                snapshot.nextFireDate(after: now, calendar: calendar).map { (snapshot, $0) }
            }
            .min { $0.1 < $1.1 }

        guard let (snapshot, fireDate) = upcoming else {
            return WatchAlarmStatus(time: nil, enabled: false)
        }
        let name = snapshot.name ?? ""
        return WatchAlarmStatus(
            time: fireDate,
            enabled: true,
            smartWake: snapshot.smartWakeEnabled,
            window: Int(snapshot.smartWakeWindow),
            name: name.isEmpty ? "Alarm" : name
        )
    }

    /// Fetches the latest completed session and/or the next alarm on a background context.
    /// The completion runs on that context's queue.
    static func fetch(
        includeSleep: Bool,
        includeAlarm: Bool,
        container: NSPersistentContainer = PersistenceController.shared.container,
        now: @escaping () -> Date = Date.init,
        completion: @escaping (_ sleepSummary: WatchSleepSummary?, _ alarmStatus: WatchAlarmStatus?) -> Void
    ) {
        let context = container.newBackgroundContext()
        context.perform {
            var sleepSummary: WatchSleepSummary?
            var alarmStatus: WatchAlarmStatus?

            if includeSleep {
                let request: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
                request.sortDescriptors = [NSSortDescriptor(keyPath: \SleepSession.endTime, ascending: false)]
                request.predicate = NSPredicate(format: "endTime != nil AND isActive == NO")
                request.fetchLimit = 1

                do {
                    if let latestSession = try context.fetch(request).first {
                        sleepSummary = watchSleepSummary(for: latestSession)
                    }
                } catch {
                    ZeezLogger.error(ZeezLogger.coreData, "Error fetching sleep data for watch", error: error)
                }
            }

            if includeAlarm {
                let request: NSFetchRequest<AlarmConfiguration> = AlarmConfiguration.fetchRequest()
                request.predicate = NSPredicate(format: "enabled == YES AND time != nil")

                do {
                    let snapshots = try context.fetch(request).compactMap(AlarmSnapshot.init)
                    alarmStatus = nextAlarmStatus(from: snapshots, now: now())
                } catch {
                    ZeezLogger.error(ZeezLogger.coreData, "Error fetching alarm data for watch", error: error)
                }
            }

            completion(sleepSummary, alarmStatus)
        }
    }
}
