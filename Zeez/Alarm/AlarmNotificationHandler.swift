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

    private let center: AlarmNotificationScheduling
    /// Tests pass an in-memory container; nil means PersistenceController.shared
    /// (resolved lazily so constructing the singleton never touches the store).
    private let container: NSPersistentContainer?
    /// Prevent double follow-up scheduling if multiple notifications present nearly at once.
    private var followupsGuard: [String: Date] = [:]

    /// Tests inject an in-memory fake center + container; production uses the real ones.
    init(notificationCenter: AlarmNotificationScheduling = UNUserNotificationCenter.current(),
         container: NSPersistentContainer? = nil) {
        self.center = notificationCenter
        self.container = container
        super.init()
    }

    private var resolvedContainer: NSPersistentContainer {
        container ?? PersistenceController.shared.container
    }

    // MARK: Presentation while foregrounded
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        ZeezLogger.info(ZeezLogger.alarm, "🔔 Alarm notification will present: \(notification.request.identifier)")

        handleNotificationArrived(notification)

        // A main alarm firing while the app is open should ring like an
        // alarm, not sit as a banner: show the full-screen alarm UI and
        // start looped audio immediately (roadmap 1.1 / audit 8.7).
        let info = notification.request.content.userInfo
        if (info["type"] as? String) ?? "main" == "main",
           let alarmId = info["alarmID"] as? String, !alarmId.isEmpty {
            prewarmAudio()
            presentActiveAlarmUI(alarmId: alarmId)
            startContinuousAudio()
        }

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
            // The cancel above consumed the pre-scheduled chain — re-arm it
            // for the alarm's NEXT firing (runs fine from a background
            // activation, which is how action handlers execute when the app
            // is killed).
            AlarmScheduler.shared.rearmFollowUpChain(alarmId: alarmId)

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

        // Delegate callbacks run off the main thread, so the alarm's settings
        // are read via a snapshot on a background context (item 1.6). Missing
        // alarm falls back to normal-mode defaults, matching prior behavior.
        AlarmSnapshot.fetch(idString: alarmId, container: resolvedContainer) { [weak self] snapshot in
            guard let self = self else { return }
            let isHeavySleeper = snapshot?.heavySleeperMode ?? false
            let cadence = AlarmNotificationUtils.getCadence(isHeavySleeper: isHeavySleeper)
            let maxCount = AlarmNotificationUtils.getMaxFollowUps(isHeavySleeper: isHeavySleeper)

            // The app is foregrounded at fire time, so the dynamic chain
            // (anchored at the actual fire moment) supersedes any
            // pre-scheduled or snooze chain — remove those first so the two
            // mechanisms never double-fire (roadmap 1.1).
            self.center.getPendingNotificationRequests { requests in
                let stale = requests.map(\.identifier).filter { $0.contains("alarm-\(alarmId)-fu-") }
                if !stale.isEmpty {
                    self.center.removePendingNotificationRequests(withIdentifiers: stale)
                    ZeezLogger.info(ZeezLogger.alarm, "♻️ Replaced \(stale.count) pre-armed follow-ups with a dynamic chain for alarm \(alarmId)")
                }
                self.scheduleFollowUps(alarmId: alarmId, cadence: cadence, maxCount: maxCount, snapshot: snapshot)
            }
        }
    }

    // Internal for tests (exercised via the injected fake center).
    func scheduleFollowUps(alarmId: String, cadence: TimeInterval, maxCount: Int, snapshot: AlarmSnapshot?) {
        let alarmSound = snapshot?.alarmSound ?? "Alarm_Classic.caf"
        let vibrationOnly = snapshot?.vibrationOnly ?? false
        let watchHaptics = snapshot?.watchHaptics ?? false

        // Start Watch haptics if enabled
        if watchHaptics {
            startWatchHaptics()
        }

        center.criticalAlertsEnabled { [weak self] useCritical in
            guard let self = self else { return }
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
                self.center.add(.init(identifier: id, content: content, trigger: trigger), withCompletionHandler: nil)
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

    // Internal for tests (exercised via the injected fake center).
    func cancelFollowUps(for alarmId: String) {
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
        // The UI wants the managed object, so the viewContext fetch must happen
        // on the main thread — delegate callbacks arrive off it (item 1.6).
        // "id" is a UUID attribute; SQLite stores cannot evaluate uuidString keypaths in predicates
        guard let uuid = UUID(uuidString: alarmId) else { return }
        DispatchQueue.main.async { [self] in
            let context = resolvedContainer.viewContext
            let request: NSFetchRequest<AlarmConfiguration> = AlarmConfiguration.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)

            do {
                if let alarm = try context.fetch(request).first {
                    NotificationCenter.default.post(
                        name: .showActiveAlarm,
                        object: alarm
                    )
                    ZeezLogger.info(ZeezLogger.alarm, "📱 Posted ShowActiveAlarm notification")
                }
            } catch {
                ZeezLogger.error(ZeezLogger.alarm, "Error fetching alarm for UI presentation", error: error)
            }
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