import Foundation
import WatchConnectivity
import CoreData
import os.log

/// Enhanced watch communication handler with improved reliability and features
class EnhancedWatchConnectivityHandler: NSObject, ObservableObject {
    static let shared = EnhancedWatchConnectivityHandler()
    
    @Published var isWatchAvailable = false
    @Published var connectionQuality: ConnectionQuality = .none
    @Published var lastSyncTime: Date?
    @Published var pendingMessages: Int = 0
    
    private var session: WCSession
    private let messageQueue = WatchMessageQueue()
    private let syncCoordinator = WatchSyncCoordinator()
    private let compressionManager = WatchDataCompression()
    private var retryManager = RetryManager()
    
    // Connection monitoring
    private var connectionTimer: Timer?
    private var heartbeatInterval: TimeInterval = 30
    private var missedHeartbeats = 0
    private let maxMissedHeartbeats = 3
    
    enum ConnectionQuality: String, CaseIterable {
        case none = "No Connection"
        case poor = "Poor"
        case good = "Good"
        case excellent = "Excellent"
    }
    
    override private init() {
        self.session = WCSession.default
        super.init()
        
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
            startConnectionMonitoring()
        }
    }
    
    // MARK: - Connection Monitoring
    
    private func startConnectionMonitoring() {
        connectionTimer = Timer.scheduledTimer(withTimeInterval: heartbeatInterval, repeats: true) { [weak self] _ in
            self?.sendHeartbeat()
        }
    }
    
    private func sendHeartbeat() {
        guard session.isReachable else {
            handleMissedHeartbeat()
            return
        }
        
        let heartbeat = WatchMessage(
            type: WatchMessageType.heartbeat,
            data: ["timestamp": Date().timeIntervalSince1970],
            priority: MessagePriority.low
        )
        
        sendMessage(heartbeat) { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    self?.missedHeartbeats = 0
                    self?.updateConnectionQuality()
                } else {
                    self?.handleMissedHeartbeat()
                }
            }
        }
    }
    
    private func handleMissedHeartbeat() {
        missedHeartbeats += 1
        updateConnectionQuality()
        
        if missedHeartbeats >= maxMissedHeartbeats {
            ZeezLogger.info(ZeezLogger.network, "Watch connection appears lost - attempting reconnection")
            attemptReconnection()
        }
    }
    
    private func updateConnectionQuality() {
        let quality: ConnectionQuality
        
        if !session.isReachable {
            quality = .none
        } else if missedHeartbeats >= 2 {
            quality = .poor
        } else if missedHeartbeats == 1 {
            quality = .good
        } else {
            quality = .excellent
        }
        
        DispatchQueue.main.async {
            self.connectionQuality = quality
        }
    }
    
    private func attemptReconnection() {
        if WCSession.isSupported() {
            session.activate()
            
            // Reset heartbeat tracking
            missedHeartbeats = 0
            
            // Resend any failed messages
            messageQueue.retryFailedMessages { [weak self] message in
                self?.sendMessage(message, completion: nil)
            }
        }
    }
    
    // MARK: - Enhanced Message Sending
    
    func sendMessage(_ message: WatchMessage, completion: ((Bool) -> Void)? = nil) {
        // Add to queue for reliability
        messageQueue.enqueue(message)
        
        DispatchQueue.main.async {
            self.pendingMessages = self.messageQueue.pendingCount
        }
        
        // Attempt immediate send if watch is reachable
        if session.isReachable {
            performSend(message, completion: completion)
        } else {
            // Queue for later send
            ZeezLogger.debug(ZeezLogger.network, "Watch not reachable - message queued: \(message.type.rawValue)")
            completion?(false)
        }
    }
    
    private func performSend(_ message: WatchMessage, completion: ((Bool) -> Void)?) {
        do {
            let messageDict = try message.toDictionary()
            
            // Compress large payloads
            let compressedDict = compressionManager.compressIfNeeded(messageDict)
            
            switch message.priority {
            case .high:
                // Use sendMessage for immediate delivery
                session.sendMessage(compressedDict, replyHandler: { reply in
                    self.handleMessageSuccess(message, reply: reply)
                    completion?(true)
                }, errorHandler: { error in
                    self.handleMessageFailure(message, error: error)
                    completion?(false)
                })
                
            case .medium:
                // Use application context for moderate priority
                try session.updateApplicationContext(compressedDict)
                handleMessageSuccess(message, reply: nil)
                completion?(true)
                
            case .low:
                // Use user info for low priority
                session.transferUserInfo(compressedDict)
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
        
        // Handle any reply data
        if let reply = reply {
            handleReply(reply, for: message)
        }
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
    
    private func handleReply(_ reply: [String: Any], for message: WatchMessage) {
        // Process specific reply types
        switch message.type {
        case .requestData:
            // Handle data request replies
            if let status = reply["status"] as? String {
                ZeezLogger.debug(ZeezLogger.network, "Data request reply: \(status)")
            }
            
        case .wakePattern:
            // Handle wake pattern acknowledgment
            if let acknowledged = reply["acknowledged"] as? Bool, acknowledged {
                ZeezLogger.info(ZeezLogger.network, "Wake pattern acknowledged by watch")
            }
            
        default:
            break
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
    
    func updateAlarmContext(_ alarm: AlarmConfiguration) {
        guard let alarmTime = alarm.time else { return }
        
        let alarmData: [String: Any] = [
            "type": "alarmUpdate",
            "alarmID": alarm.id?.uuidString ?? "",
            "time": alarmTime.timeIntervalSince1970,
            "enabled": alarm.enabled,
            "smartWake": alarm.smartWakeEnabled,
            "smartWakeWindow": alarm.smartWakeWindow,
            "name": alarm.name ?? "Alarm"
        ]
        
        let message = WatchMessage(
            type: WatchMessageType.alarmStatus,
            data: alarmData,
            priority: MessagePriority.medium
        )
        
        sendMessage(message)
    }
    
    func syncSleepData() {
        guard let sleepSummary = getCurrentSleepSummary() else {
            ZeezLogger.debug(ZeezLogger.network, "No sleep data available for watch sync")
            return
        }
        
        let message = WatchMessage(
            type: WatchMessageType.sleepSummary,
            data: sleepSummary,
            priority: MessagePriority.medium
        )
        
        sendMessage(message)
    }
    
    func requestWatchStatus() {
        let message = WatchMessage(
            type: WatchMessageType.requestData,
            data: ["requestType": "status"],
            priority: MessagePriority.medium
        )
        
        sendMessage(message)
    }
    
    // MARK: - Data Preparation
    
    private func getCurrentSleepSummary() -> [String: Any]? {
        let context = PersistenceController.shared.container.viewContext
        
        let request: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SleepSession.endTime, ascending: false)]
        request.predicate = NSPredicate(format: "endTime != nil AND isActive == NO")
        request.fetchLimit = 1
        
        do {
            guard let latestSession = try context.fetch(request).first else {
                return nil
            }

            return watchSleepSummaryPayload(for: latestSession)
            
        } catch {
            ZeezLogger.error(ZeezLogger.coreData, "Error fetching sleep data for watch", error: error)
            return nil
        }
    }
    
    private func getNextAlarmStatus() -> [String: Any]? {
        let context = PersistenceController.shared.container.viewContext
        
        let request: NSFetchRequest<AlarmConfiguration> = AlarmConfiguration.fetchRequest()
        request.predicate = NSPredicate(format: "enabled == YES AND time != nil")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \AlarmConfiguration.time, ascending: true)]
        request.fetchLimit = 1
        
        do {
            guard let nextAlarm = try context.fetch(request).first,
                  let alarmTime = nextAlarm.time else {
                return nil
            }
            
            return [
                "time": alarmTime.timeIntervalSince1970,
                "enabled": nextAlarm.enabled,
                "smartWake": nextAlarm.smartWakeEnabled,
                "smartWakeWindow": Int(nextAlarm.smartWakeWindow),
                "name": nextAlarm.name ?? "Alarm"
            ]
            
        } catch {
            ZeezLogger.error(ZeezLogger.coreData, "Error fetching alarm data for watch", error: error)
            return nil
        }
    }
    
    // MARK: - Sync Management
    
    func performFullSync() {
        ZeezLogger.info(ZeezLogger.network, "Performing full watch sync")
        
        // Send sleep data
        syncSleepData()
        
        // Send alarm data
        if let alarmData = getNextAlarmStatus() {
            let message = WatchMessage(
                type: WatchMessageType.alarmStatus,
                data: alarmData,
                priority: MessagePriority.medium
            )
            sendMessage(message)
        }
        
        // Update sync timestamp
        DispatchQueue.main.async {
            self.lastSyncTime = Date()
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
    
    deinit {
        connectionTimer?.invalidate()
    }
}

// MARK: - WCSessionDelegate
extension EnhancedWatchConnectivityHandler: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async {
            self.isWatchAvailable = activationState == .activated
            
            if activationState == .activated {
                ZeezLogger.info(ZeezLogger.network, "Watch connectivity activated")
                self.missedHeartbeats = 0
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
        // Reactivate for future connections
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
        // Decompress if needed
        let decompressedMessage = compressionManager.decompressIfNeeded(message)
        
        guard let command = decompressedMessage["command"] as? String else {
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
            handleDataRequest(decompressedMessage, replyHandler: replyHandler)
            
        case "heartbeat":
            // Respond to heartbeat
            replyHandler?(["heartbeat": "pong", "timestamp": Date().timeIntervalSince1970])
            
        case "statusUpdate":
            handleStatusUpdate(decompressedMessage)
            replyHandler?(["status": "received"])
            
        default:
            ZeezLogger.info(ZeezLogger.network, "Unknown watch command: \(command)")
            replyHandler?(["error": "Unknown command"])
        }
    }
    
    private func handleDataRequest(_ message: [String: Any], replyHandler: (([String: Any]) -> Void)?) {
        var responseData: [String: Any] = [:]
        
        let requestType = message["requestType"] as? String ?? "all"
        
        switch requestType {
        case "sleep", "all":
            if let sleepSummary = getCurrentSleepSummary() {
                responseData["sleepSummary"] = sleepSummary
            }
            
        case "alarm", "all":
            if let alarmStatus = getNextAlarmStatus() {
                responseData["alarmStatus"] = alarmStatus
            }
            
        case "status":
            responseData["connectionInfo"] = getConnectionInfo()
            
        default:
            break
        }
        
        replyHandler?(responseData)
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
