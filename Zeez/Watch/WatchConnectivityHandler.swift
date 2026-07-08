import Foundation
import WatchConnectivity
import CoreData
import os.log

/// Builds the typed watch summary from a session. Must be called on the
/// session's context queue; the returned value is a plain struct that can
/// cross queues freely. Wire shape lives in Shared/WatchDataModels.swift.
func watchSleepSummary(for session: SleepSession) -> WatchSleepSummary? {
    guard let endTime = session.endTime,
          let startTime = session.startTime,
          let recordedInterval = session.derivedSleepMetrics.recordedSessionInterval.value else {
        return nil
    }

    return WatchSleepSummary(
        duration: recordedInterval,
        quality: session.hasDisplayableScore ? session.qualityScore : 0,
        qualityAvailable: session.hasDisplayableScore,
        bedTime: startTime,
        wakeTime: endTime
    )
}

/// Enhanced watch communication handler with improved reliability and features
class WatchConnectivityHandler: NSObject, ObservableObject {
    static let shared = WatchConnectivityHandler()
    
    @Published var isWatchAvailable = false
    @Published var connectionQuality: ConnectionQuality = .none
    @Published var lastSyncTime: Date?
    @Published var pendingMessages: Int = 0
    
    private var session: WCSession
    private let messageQueue = WatchMessageQueue()
    private var retryManager = RetryManager()

    /// Reachability-derived only. The old phone-side heartbeat machinery sent
    /// low-priority userInfo transfers the watch never read and reported
    /// unconditional success, so the "quality" it graded was fiction (A5).
    enum ConnectionQuality: String, CaseIterable {
        case none = "No Connection"
        case good = "Good"
    }

    override private init() {
        self.session = WCSession.default
        super.init()

        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }

    // MARK: - Connection Monitoring

    private func updateConnectionQuality() {
        let quality: ConnectionQuality = session.isReachable ? .good : .none

        DispatchQueue.main.async {
            self.connectionQuality = quality
        }
    }

    // MARK: - Enhanced Message Sending
    
    func sendMessage(_ message: WatchMessage, completion: ((Bool) -> Void)? = nil) {
        // Add to queue for reliability
        messageQueue.enqueue(message)
        
        DispatchQueue.main.async {
            self.pendingMessages = self.messageQueue.pendingCount
        }
        
        // Only interactive sendMessage needs a reachable counterpart;
        // updateApplicationContext delivers whenever the watch next runs.
        if message.priority == .high && !session.isReachable {
            ZeezLogger.debug(ZeezLogger.network, "Watch not reachable - message queued: \(message.type.rawValue)")
            completion?(false)
            return
        }

        performSend(message, completion: completion)
    }

    private func performSend(_ message: WatchMessage, completion: ((Bool) -> Void)?) {
        do {
            let messageDict = try message.toDictionary()

            switch message.priority {
            case .high:
                session.sendMessage(messageDict, replyHandler: { reply in
                    self.handleMessageSuccess(message, reply: reply)
                    completion?(true)
                }, errorHandler: { error in
                    self.handleMessageFailure(message, error: error)
                    completion?(false)
                })

            case .medium, .low:
                try session.updateApplicationContext(messageDict)
                handleMessageSuccess(message, reply: nil)
                completion?(true)
            }

        } catch {
            ZeezLogger.error(ZeezLogger.network, "Failed to prepare watch message", error: error)
            handleMessageFailure(message, error: error)
            completion?(false)
        }
    }
    
    private func handleMessageSuccess(_ message: WatchMessage, reply: [String: Any]?) {
        messageQueue.markAsCompleted(message)
        
        DispatchQueue.main.async {
            self.pendingMessages = self.messageQueue.pendingCount
            self.lastSyncTime = Date()
        }
        
        ZeezLogger.debug(ZeezLogger.network, "Watch message sent successfully: \(message.type.rawValue)")
    }
    
    private func handleMessageFailure(_ message: WatchMessage, error: Error) {
        let shouldRetry = retryManager.shouldRetry(message, error: error)
        
        if shouldRetry {
            ZeezLogger.info(ZeezLogger.network, "Will retry watch message: \(message.type.rawValue)")
            messageQueue.markForRetry(message)
        } else {
            ZeezLogger.error(ZeezLogger.network, "Watch message failed permanently: \(message.type.rawValue)", error: error)
            messageQueue.markAsFailed(message)
        }
        
        DispatchQueue.main.async {
            self.pendingMessages = self.messageQueue.pendingCount
        }
    }
    
    // MARK: - High-Level Communication Methods
    
    func sendWakePattern(_ pattern: HapticPattern, intensity: Double, duration: TimeInterval = 30) {
        let message = WatchMessage(
            type: WatchMessageType.wakePattern,
            data: [
                "pattern": pattern.rawValue,
                "intensity": intensity,
                "duration": duration,
                "timestamp": Date().timeIntervalSince1970
            ],
            priority: MessagePriority.high
        )
        
        sendMessage(message) { success in
            if success {
                ZeezLogger.info(ZeezLogger.network, "Wake pattern sent to watch: \(pattern.rawValue)")
            } else {
                ZeezLogger.error(ZeezLogger.network, "Failed to send wake pattern to watch")
            }
        }
    }
    
    func stopWakePattern() {
        let message = WatchMessage(
            type: WatchMessageType.stopPattern,
            data: ["timestamp": Date().timeIntervalSince1970],
            priority: MessagePriority.high
        )
        
        sendMessage(message)
    }
    
    /// Must be called on `alarm`'s context queue; only plain values are
    /// captured into the outgoing message.
    func updateAlarmContext(_ alarm: AlarmConfiguration) {
        guard let alarmTime = alarm.time else { return }

        let alarmStatus = WatchAlarmStatus(
            time: alarmTime,
            enabled: alarm.enabled,
            smartWake: alarm.smartWakeEnabled,
            window: Int(alarm.smartWakeWindow),
            name: alarm.name ?? "Alarm"
        )

        sendMessage(WatchMessage(
            type: WatchMessageType.alarmStatus,
            data: WatchSyncEnvelope(alarmStatus: alarmStatus).toDictionary(),
            priority: MessagePriority.medium
        ))
    }

    func syncSleepData() {
        fetchWatchPayloads(includeSleep: true, includeAlarm: false) { [weak self] sleepSummary, _ in
            guard let self else { return }
            guard let sleepSummary else {
                ZeezLogger.debug(ZeezLogger.network, "No sleep data available for watch sync")
                return
            }

            self.sendMessage(WatchMessage(
                type: WatchMessageType.sleepSummary,
                data: WatchSyncEnvelope(sleepSummary: sleepSummary).toDictionary(),
                priority: MessagePriority.medium
            ))
        }
    }

    func performFullSync() {
        ZeezLogger.info(ZeezLogger.network, "Performing full watch sync")

        fetchWatchPayloads(includeSleep: true, includeAlarm: true) { [weak self] sleepSummary, alarmStatus in
            guard let self else { return }

            let envelope = WatchSyncEnvelope(sleepSummary: sleepSummary, alarmStatus: alarmStatus)
            guard !envelope.isEmpty else { return }

            // Both payloads travel in ONE message: .medium maps to
            // updateApplicationContext, whose single slot means a second
            // sequential push would replace the first before delivery.
            self.sendMessage(WatchMessage(
                type: WatchMessageType.sleepSummary,
                data: envelope.toDictionary(),
                priority: MessagePriority.medium
            ))

            DispatchQueue.main.async {
                self.lastSyncTime = Date()
            }
        }
    }

    // MARK: - Data Preparation

    /// Builds the typed watch payloads inside a background context's queue.
    ///
    /// Callers arrive on arbitrary queues (WCSession delegate callbacks come in on a
    /// background queue), so managed objects are never touched directly here — only
    /// plain value types cross back out, per the alarm-stack snapshot pattern.
    /// The completion runs on the background context's queue.
    private func fetchWatchPayloads(
        includeSleep: Bool,
        includeAlarm: Bool,
        completion: @escaping (_ sleepSummary: WatchSleepSummary?, _ alarmStatus: WatchAlarmStatus?) -> Void
    ) {
        let context = PersistenceController.shared.newBackgroundContext()
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
                request.sortDescriptors = [NSSortDescriptor(keyPath: \AlarmConfiguration.time, ascending: true)]
                request.fetchLimit = 1

                do {
                    if let nextAlarm = try context.fetch(request).first,
                       let alarmTime = nextAlarm.time {
                        alarmStatus = WatchAlarmStatus(
                            time: alarmTime,
                            enabled: nextAlarm.enabled,
                            smartWake: nextAlarm.smartWakeEnabled,
                            window: Int(nextAlarm.smartWakeWindow),
                            name: nextAlarm.name ?? "Alarm"
                        )
                    }
                } catch {
                    ZeezLogger.error(ZeezLogger.coreData, "Error fetching alarm data for watch", error: error)
                }
            }

            completion(sleepSummary, alarmStatus)
        }
    }
    
    // MARK: - Public Interface
    
    func getConnectionInfo() -> [String: Any] {
        return [
            "isReachable": session.isReachable,
            "isPaired": session.isPaired,
            "isWatchAppInstalled": session.isWatchAppInstalled,
            "connectionQuality": connectionQuality.rawValue,
            "pendingMessages": pendingMessages,
            "lastSyncTime": lastSyncTime?.timeIntervalSince1970 ?? 0
        ]
    }
    
    func clearMessageQueue() {
        messageQueue.clear()
        DispatchQueue.main.async {
            self.pendingMessages = 0
        }
    }
}

// MARK: - WCSessionDelegate
extension WatchConnectivityHandler: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async {
            self.isWatchAvailable = activationState == .activated
            
            if activationState == .activated {
                ZeezLogger.info(ZeezLogger.network, "Watch connectivity activated")
                self.updateConnectionQuality()
                
                // Perform initial sync
                self.performFullSync()
            } else if let error = error {
                ZeezLogger.error(ZeezLogger.network, "Watch connectivity activation failed", error: error)
            }
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchAvailable = false
            self.connectionQuality = .none
        }
        ZeezLogger.info(ZeezLogger.network, "Watch session became inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchAvailable = false
            self.connectionQuality = .none
        }
        
        ZeezLogger.info(ZeezLogger.network, "Watch session deactivated - reactivating")
        session.activate()
    }
    
    #if os(iOS)
    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchAvailable = session.isReachable
            self.updateConnectionQuality()
            
            if session.isReachable {
                // Resend any queued messages
                self.messageQueue.retryFailedMessages { [weak self] message in
                    self?.sendMessage(message, completion: nil)
                }
            }
        }
        
        ZeezLogger.info(ZeezLogger.network, "Watch state changed - reachable: \(session.isReachable)")
    }
    
    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        handleWatchMessage(message, replyHandler: replyHandler)
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        handleWatchMessage(message, replyHandler: nil)
    }
    #endif
    
    private func handleWatchMessage(
        _ message: [String: Any],
        replyHandler: (([String: Any]) -> Void)?
    ) {
        guard let command = message["command"] as? String else {
            replyHandler?(["error": "Invalid command"])
            return
        }

        ZeezLogger.debug(ZeezLogger.network, "Received watch message: \(command)")

        switch command {
        case "acknowledge":
            WakeUpProgressionManager.shared.acknowledgeWakeUp()
            replyHandler?(["status": "success", "timestamp": Date().timeIntervalSince1970])

        case "snooze":
            WakeUpProgressionManager.shared.snoozeWakeUp()
            replyHandler?(["status": "success", "timestamp": Date().timeIntervalSince1970])

        case "requestData":
            handleDataRequest(message, replyHandler: replyHandler)

        case "heartbeat":
            // Respond to heartbeat
            replyHandler?(["heartbeat": "pong", "timestamp": Date().timeIntervalSince1970])
            
        case "statusUpdate":
            handleStatusUpdate(message)
            replyHandler?(["status": "received"])
            
        default:
            ZeezLogger.info(ZeezLogger.network, "Unknown watch command: \(command)")
            replyHandler?(["error": "Unknown command"])
        }
    }
    
    private func handleDataRequest(_ message: [String: Any], replyHandler: (([String: Any]) -> Void)?) {
        let requestType = message["requestType"] as? String ?? "all"

        guard requestType == "sleep" || requestType == "alarm" || requestType == "all" else {
            if requestType == "status" {
                replyHandler?(["connectionInfo": getConnectionInfo()])
            } else {
                replyHandler?([:])
            }
            return
        }

        fetchWatchPayloads(
            includeSleep: requestType == "sleep" || requestType == "all",
            includeAlarm: requestType == "alarm" || requestType == "all"
        ) { sleepSummary, alarmStatus in
            let envelope = WatchSyncEnvelope(sleepSummary: sleepSummary, alarmStatus: alarmStatus)
            replyHandler?(envelope.toDictionary())
        }
    }
    
    private func handleStatusUpdate(_ message: [String: Any]) {
        // Handle status updates from watch (battery level, app state, etc.)
        if let batteryLevel = message["batteryLevel"] as? Double {
            ZeezLogger.debug(ZeezLogger.network, "Watch battery level: \(Int(batteryLevel * 100))%")
        }
        
        if let appState = message["appState"] as? String {
            ZeezLogger.debug(ZeezLogger.network, "Watch app state: \(appState)")
        }
    }
}
