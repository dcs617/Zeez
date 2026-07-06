import UserNotifications
import UIKit
import CoreData
import AVFoundation
import os.log

/// Single UNUserNotificationCenterDelegate that:
///  - schedules finite follow-ups when the main alarm fires,
///  - handles Stop / Snooze / Continue,
///  - opens the app and starts true looping audio on Continue/tap.
final class AlarmNotificationHandler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = AlarmNotificationHandler()

    private let center = UNUserNotificationCenter.current()
    /// Prevent double follow-up scheduling if multiple notifications present nearly at once.
    private var followupsGuard: [String: Date] = [:]

    // MARK: Presentation while foregrounded
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        ZeezLogger.info(ZeezLogger.alarm, "🔔 Alarm notification will present: \(notification.request.identifier)")
        
        handleNotificationArrived(notification)
        completionHandler([.banner, .sound])
    }

    // MARK: Response to taps/actions
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completion: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        let alarmId = (info["alarmID"] as? String) ?? ""
        
        ZeezLogger.info(ZeezLogger.alarm, "💆 Alarm notification response: \(response.actionIdentifier) for alarm \(alarmId)")
        
        switch response.actionIdentifier {
        case AlarmNotificationRegistrar.snoozeId:
            ZeezLogger.info(ZeezLogger.alarm, "   User chose SNOOZE")
            cancelFollowUps(for: alarmId)
            resetFollowUpGuard(for: alarmId)
            AlarmNotificationUtils.scheduleSnooze(for: alarmId)
            AlarmAudioController.shared.stop()

        case AlarmNotificationRegistrar.stopId:
            ZeezLogger.info(ZeezLogger.alarm, "   User chose STOP")
            cancelFollowUps(for: alarmId)
            resetFollowUpGuard(for: alarmId)
            AlarmAudioController.shared.stop()

        case AlarmNotificationRegistrar.contId,
             UNNotificationDefaultActionIdentifier: // tapped the banner
            ZeezLogger.info(ZeezLogger.alarm, "   User chose CONTINUE or tapped notification")
            // Prewarm audio for instant start, then foreground UI and start looped audio
            prewarmAudio()
            presentActiveAlarmUI(alarmId: alarmId)
            startContinuousAudio()
            cancelFollowUps(for: alarmId)
            resetFollowUpGuard(for: alarmId)

        default:
            ZeezLogger.info(ZeezLogger.alarm, "   Unknown action: \(response.actionIdentifier)")
            break
        }
        completion()
    }

    // MARK: Internal

    private func handleNotificationArrived(_ notification: UNNotification) {
        let info = notification.request.content.userInfo
        let alarmId = (info["alarmID"] as? String) ?? ""
        let type    = (info["type"] as? String) ?? "main"
        
        guard !alarmId.isEmpty, type == "main" else { return }

        // Only once every ~2 minutes to avoid duplicates.
        if let ts = followupsGuard[alarmId], Date().timeIntervalSince(ts) < 120 { return }
        followupsGuard[alarmId] = Date()
        
        // Check if this alarm has heavy sleeper mode enabled
        let isHeavySleeper = checkHeavySleeperMode(for: alarmId)
        let cadence = AlarmNotificationUtils.getCadence(isHeavySleeper: isHeavySleeper)
        let maxCount = AlarmNotificationUtils.getMaxFollowUps(isHeavySleeper: isHeavySleeper)
        
        scheduleFollowUps(alarmId: alarmId, cadence: cadence, maxCount: maxCount)
    }
    
    private func checkHeavySleeperMode(for alarmId: String) -> Bool {
        // Check the alarm configuration in Core Data
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<AlarmConfiguration> = AlarmConfiguration.fetchRequest()
        request.predicate = NSPredicate(format: "id.uuidString == %@", alarmId)
        
        do {
            if let alarm = try context.fetch(request).first {
                // Assuming you'll add a heavySleeperMode property to AlarmConfiguration
                return alarm.value(forKey: "heavySleeperMode") as? Bool ?? false
            }
        } catch {
            ZeezLogger.error(ZeezLogger.alarm, "Error fetching alarm for heavy sleeper check", error: error)
        }
        
        return false
    }

    private func scheduleFollowUps(alarmId: String, cadence: TimeInterval, maxCount: Int) {
        // Get the alarm configuration to use its sound and watch settings
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<AlarmConfiguration> = AlarmConfiguration.fetchRequest()
        request.predicate = NSPredicate(format: "id.uuidString == %@", alarmId)
        
        var alarmSound: String = "Alarm_Classic.caf"
        var vibrationOnly = false
        var watchHaptics = false
        
        do {
            if let alarm = try context.fetch(request).first {
                alarmSound = alarm.alarmSound ?? "Alarm_Classic.caf"
                vibrationOnly = alarm.vibrationOnly
                watchHaptics = alarm.watchHaptics
            }
        } catch {
            ZeezLogger.error(ZeezLogger.alarm, "Error fetching alarm for follow-up sound selection", error: error)
        }
        
        // Start Watch haptics if enabled
        if watchHaptics {
            startWatchHaptics()
        }
        
        center.getNotificationSettings { [weak self] settings in
            guard let self = self else { return }
            let useCritical = (settings.criticalAlertSetting == .enabled)
            let base = Date().timeIntervalSince1970

            (1...maxCount).forEach { n in
                let content = UNMutableNotificationContent()
                content.title = ""
                content.body = ""
                content.categoryIdentifier = AlarmNotificationRegistrar.categoryId
                content.userInfo = ["alarmID": alarmId, "type": "fu"]
                content.interruptionLevel = useCritical ? .critical : .timeSensitive
                
                // Use the same sound as the main alarm
                if vibrationOnly {
                    content.sound = nil
                } else {
                    content.sound = self.getFollowUpSound(alarmSound: alarmSound, criticalEnabled: useCritical)
                }

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: cadence * Double(n), repeats: false)
                let id = "alarm-\(alarmId)-fu-\(n)-\(Int(base))"
                self.center.add(.init(identifier: id, content: content, trigger: trigger))
            }
            
            let mode = cadence == AlarmNotificationUtils.heavySleeperCadenceSeconds ? "Heavy Sleeper" : "Normal"
            ZeezLogger.info(ZeezLogger.alarm, "📅 Scheduled \(maxCount) follow-ups (\(mode) mode, \(Int(cadence))s intervals) with sound: \(alarmSound) for alarm \(alarmId)")
        }
    }
    
    private func getFollowUpSound(alarmSound: String, criticalEnabled: Bool) -> UNNotificationSound {
        // Check for Zeez custom sounds first
        switch alarmSound {
        case "Alarm_Classic.caf":
            return UNNotificationSound(named: UNNotificationSoundName("Alarm_Classic.caf"))
        case "Alarm_Honk.caf":
            return UNNotificationSound(named: UNNotificationSoundName("Alarm_Honk.caf"))
        case "Alarm_Horn.caf":
            return UNNotificationSound(named: UNNotificationSoundName("Alarm_Horn.caf"))
        case "default":
            return criticalEnabled ? .defaultCritical : .default
        default:
            // Try as custom sound file
            if !alarmSound.isEmpty {
                return UNNotificationSound(named: UNNotificationSoundName(alarmSound))
            } else {
                return criticalEnabled ? .defaultCritical : .default
            }
        }
    }

    private func cancelFollowUps(for alarmId: String) {
        center.getPendingNotificationRequests { [weak self] reqs in
            let ids = reqs.map(\.identifier).filter { $0.contains("alarm-\(alarmId)-fu-") }
            if !ids.isEmpty {
                self?.center.removePendingNotificationRequests(withIdentifiers: ids)
                ZeezLogger.info(ZeezLogger.alarm, "🚫 Canceled \(ids.count) follow-ups for alarm \(alarmId)")
            }
        }
        
        // Stop Watch haptics when follow-ups are canceled
        stopWatchHaptics()
    }
    
    private func startContinuousAudio() {
        // Try to start the long audio file, fallback to default if not found
        if AlarmAudioController.shared.canPlay(bundledName: AlarmNotificationUtils.longInAppBundledName) {
            AlarmAudioController.shared.startLooping(bundledName: AlarmNotificationUtils.longInAppBundledName)
        } else {
            // Fallback to a guaranteed bundled sound
            ZeezLogger.info(ZeezLogger.alarm, "⚠️ Long alarm sound not found, using bundled fallback")
            AlarmAudioController.shared.startLooping(bundledName: "Alarm_Classic", fileExtension: "caf")
        }
    }

    /// Simple mechanism to show your full-screen ringing UI.
    /// Your SwiftUI root can observe this notification name and present ActiveAlarmView.
    private func presentActiveAlarmUI(alarmId: String) {
        // Find the full alarm object to pass to the UI
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<AlarmConfiguration> = AlarmConfiguration.fetchRequest()
        request.predicate = NSPredicate(format: "id.uuidString == %@", alarmId)
        
        do {
            if let alarm = try context.fetch(request).first {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ShowActiveAlarm"),
                        object: alarm
                    )
                    ZeezLogger.info(ZeezLogger.alarm, "📱 Posted ShowActiveAlarm notification")
                }
            }
        } catch {
            ZeezLogger.error(ZeezLogger.alarm, "Error fetching alarm for UI presentation", error: error)
        }
    }
    
    private func prewarmAudio() {
        // Prewarm the audio system for instant start
        if AlarmAudioController.shared.canPlay(bundledName: AlarmNotificationUtils.longInAppBundledName) {
            // Just prepare, don't play yet
            do {
                if let url = Bundle.main.url(forResource: AlarmNotificationUtils.longInAppBundledName, withExtension: "caf") {
                    let player = try AVAudioPlayer(contentsOf: url)
                    player.prepareToPlay()
                    ZeezLogger.info(ZeezLogger.alarm, "🎵 Audio prewarmed for instant start")
                }
            } catch {
                ZeezLogger.error(ZeezLogger.alarm, "Failed to prewarm audio", error: error)
            }
        }
    }
    
    private func resetFollowUpGuard(for alarmId: String) {
        // Reset the follow-up guard so a new main fire can re-arm follow-ups cleanly
        followupsGuard.removeValue(forKey: alarmId)
        ZeezLogger.debug(ZeezLogger.alarm, "🔄 Reset follow-up guard for alarm \(alarmId)")
    }
    
    // MARK: - Watch Haptics Integration
    
    private func startWatchHaptics() {
        guard WatchConnectivityHandler.shared.isWatchAvailable else {
            ZeezLogger.debug(ZeezLogger.alarm, "Watch not available for haptics")
            return
        }
        
        // Use moderate pattern for "still ringing" haptics
        // Duration will continue until stopWatchHaptics is called
        let pattern: HapticPattern = .moderate
        let intensity: Double = 0.7
        let duration: TimeInterval = 300 // 5 minutes max, but will be stopped earlier
        
        WatchConnectivityHandler.shared.sendWakePattern(pattern, intensity: intensity, duration: duration)
        ZeezLogger.info(ZeezLogger.alarm, "📱 Started Watch haptics for continuing alarm")
    }
    
    private func stopWatchHaptics() {
        guard WatchConnectivityHandler.shared.isWatchAvailable else { return }
        
        WatchConnectivityHandler.shared.stopWakePattern()
        ZeezLogger.info(ZeezLogger.alarm, "📱 Stopped Watch haptics")
    }
}