import Foundation
import WatchConnectivity
import SwiftUI
import WatchKit
import os.log

/// Enhanced watch connectivity manager with improved reliability and offline support
class EnhancedWatchConnectivityManager: NSObject, ObservableObject {
    static let shared = EnhancedWatchConnectivityManager()
    
    @Published var sleepSummary = WatchSleepSummary()
    @Published var alarmStatus = WatchAlarmStatus()
    @Published var isConnected = false
    @Published var connectionQuality: ConnectionQuality = .none
    @Published var isReceivingWakePattern = false
    @Published var lastSyncTime: Date?
    @Published var offlineMode = false
    
    private var session: WCSession
    private var currentWakePattern: WakePatternData?
    private let hapticManager = WatchHapticManager.shared
    private let offlineStorage = WatchOfflineStorage()
    private let messageQueue = WatchLocalMessageQueue()
    
    // Connection monitoring
    private var heartbeatTimer: Timer?
    private var connectionCheckInterval: TimeInterval = 15
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
            loadOfflineData()
        } else {
            // Watch doesn't support connectivity - enable offline mode
            offlineMode = true
        }
    }
    
    // MARK: - Connection Monitoring
    
    private func startConnectionMonitoring() {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: connectionCheckInterval, repeats: true) { [weak self] _ in
            self?.checkConnection()
        }
    }
    
    private func checkConnection() {
        if session.isReachable {
            sendHeartbeat()
        } else {
            handleConnectionLoss()
        }
    }
    
    private func sendHeartbeat() {
        let message: [String: Any] = [
            "command": "heartbeat",
            "timestamp": Date().timeIntervalSince1970,
            "batteryLevel": getCurrentBatteryLevel(),
            "appState": getCurrentAppState()
        ]
        
        session.sendMessage(message, replyHandler: { [weak self] reply in
            DispatchQueue.main.async {
                self?.handleHeartbeatReply(reply)
            }
        }) { [weak self] error in
            DispatchQueue.main.async {
                self?.handleHeartbeatError(error)
            }
        }
    }
    
    private func handleHeartbeatReply(_ reply: [String: Any]) {
        missedHeartbeats = 0
        updateConnectionQuality(.excellent)
        
        // Process any data in the heartbeat reply
        if let timestamp = reply["timestamp"] as? TimeInterval {
            let serverTime = Date(timeIntervalSince1970: timestamp)
            // Could sync time if needed
        }
    }
    
    private func handleHeartbeatError(_ error: Error) {
        missedHeartbeats += 1
        
        if missedHeartbeats >= maxMissedHeartbeats {
            handleConnectionLoss()
        } else {
            updateConnectionQuality(.poor)
        }
    }
    
    private func handleConnectionLoss() {
        updateConnectionQuality(.none)
        
        if !offlineMode {
            print("📱 Connection lost - switching to offline mode")
            enableOfflineMode()
        }
    }
    
    private func updateConnectionQuality(_ quality: ConnectionQuality) {
        DispatchQueue.main.async {
            self.connectionQuality = quality
            self.isConnected = quality != .none
        }
    }
    
    // MARK: - Offline Support
    
    private func enableOfflineMode() {
        offlineMode = true
        
        // Load cached data
        loadOfflineData()
        
        // Show user notification about offline mode
        hapticManager.playWarningFeedback()
    }
    
    private func disableOfflineMode() {
        offlineMode = false
        
        // Sync any offline actions when connection is restored
        syncOfflineActions()
    }
    
    private func loadOfflineData() {
        sleepSummary = offlineStorage.getCachedSleepSummary() ?? WatchSleepSummary()
        alarmStatus = offlineStorage.getCachedAlarmStatus() ?? WatchAlarmStatus()
        lastSyncTime = offlineStorage.getLastSyncTime()
    }
    
    private func syncOfflineActions() {
        let offlineActions = offlineStorage.getPendingActions()
        
        for action in offlineActions {
            switch action.type {
            case .acknowledge:
                acknowledgeAlarm()
            case .snooze:
                snoozeAlarm()
            case .requestData:
                requestLatestData()
            }
        }
        
        offlineStorage.clearPendingActions()
    }
    
    // MARK: - Enhanced Communication Methods
    
    func requestLatestData() {
        if !isConnected && offlineMode {
            // Use cached data in offline mode
            loadOfflineData()
            return
        }
        
        guard session.isReachable else {
            queueAction(.requestData)
            return
        }
        
        let message: [String: Any] = [
            "command": "requestData",
            "timestamp": Date().timeIntervalSince1970,
            "requestId": UUID().uuidString
        ]
        
        session.sendMessage(message, replyHandler: { [weak self] reply in
            DispatchQueue.main.async {
                self?.handleDataUpdate(reply)
                self?.cacheReceivedData(reply)
            }
        }) { error in
            print("❌ Error requesting data: \(error.localizedDescription)")
        }
    }
    
    func acknowledgeAlarm() {
        // Play haptic feedback immediately for responsiveness
        hapticManager.playSuccessFeedback()
        
        if !isConnected && offlineMode {
            queueAction(.acknowledge)
            showOfflineActionConfirmation("Alarm acknowledged (offline)")
            return
        }
        
        guard session.isReachable else {
            queueAction(.acknowledge)
            return
        }
        
        let message: [String: Any] = [
            "command": "acknowledge",
            "timestamp": Date().timeIntervalSince1970,
            "actionId": UUID().uuidString
        ]
        
        session.sendMessage(message, replyHandler: { reply in
            print("✅ Alarm acknowledged: \(reply)")
        }) { error in
            print("❌ Error acknowledging alarm: \(error.localizedDescription)")
        }
        
        stopWakePattern()
    }
    
    func snoozeAlarm() {
        // Play haptic feedback immediately
        hapticManager.playActionFeedback()
        
        if !isConnected && offlineMode {
            queueAction(.snooze)
            showOfflineActionConfirmation("Alarm snoozed (offline)")
            return
        }
        
        guard session.isReachable else {
            queueAction(.snooze)
            return
        }
        
        let message: [String: Any] = [
            "command": "snooze",
            "timestamp": Date().timeIntervalSince1970,
            "actionId": UUID().uuidString
        ]
        
        session.sendMessage(message, replyHandler: { reply in
            print("😴 Alarm snoozed: \(reply)")
        }) { error in
            print("❌ Error snoozing alarm: \(error.localizedDescription)")
        }
        
        stopWakePattern()
    }
    
    private func queueAction(_ action: OfflineAction.ActionType) {
        let offlineAction = OfflineAction(type: action, timestamp: Date())
        offlineStorage.addPendingAction(offlineAction)
        
        print("📋 Action queued for when connection returns: \(action)")
    }
    
    private func showOfflineActionConfirmation(_ message: String) {
        // This would typically show a brief UI indication
        print("💾 \(message)")
    }
    
    // MARK: - Wake Pattern Handling
    
    private func stopWakePattern() {
        isReceivingWakePattern = false
        currentWakePattern = nil
        hapticManager.stopAllPatterns()
    }
    
    private func handleWakePattern(from data: [String: Any]) {
        guard let patternString = data["pattern"] as? String,
              let pattern = HapticPattern(rawValue: patternString),
              let intensity = data["intensity"] as? Double else {
            print("❌ Invalid wake pattern data received")
            return
        }
        
        let duration = data["duration"] as? TimeInterval ?? 30
        let wakePattern = WakePatternData(pattern: pattern, intensity: intensity, duration: duration)
        
        currentWakePattern = wakePattern
        isReceivingWakePattern = true
        
        print("⏰ Starting wake pattern: \(pattern.rawValue) at \(intensity) intensity")
        hapticManager.startWakePattern(wakePattern)
    }
    
    // MARK: - Data Handling
    
    private func handleDataUpdate(_ data: [String: Any]) {
        if let sleepData = data["sleepSummary"] as? [String: Any] {
            updateSleepSummary(from: sleepData)
        }
        
        if let alarmData = data["alarmStatus"] as? [String: Any] {
            updateAlarmStatus(from: alarmData)
        }
        
        lastSyncTime = Date()
    }
    
    private func cacheReceivedData(_ data: [String: Any]) {
        if let sleepData = data["sleepSummary"] as? [String: Any] {
            offlineStorage.cacheSleepSummary(sleepData)
        }
        
        if let alarmData = data["alarmStatus"] as? [String: Any] {
            offlineStorage.cacheAlarmStatus(alarmData)
        }
        
        offlineStorage.updateLastSyncTime(Date())
    }
    
    private func updateSleepSummary(from data: [String: Any]) {
        let duration = data["duration"] as? TimeInterval ?? 0
        let quality = data["quality"] as? Double ?? 0
        let qualityAvailable = data["qualityAvailable"] as? Bool ?? false
        let bedTime = (data["bedTime"] as? TimeInterval).map { Date(timeIntervalSince1970: $0) }
        let wakeTime = (data["wakeTime"] as? TimeInterval).map { Date(timeIntervalSince1970: $0) }
        
        sleepSummary = WatchSleepSummary(
            duration: duration,
            quality: quality,
            qualityAvailable: qualityAvailable,
            bedTime: bedTime,
            wakeTime: wakeTime
        )
    }
    
    private func updateAlarmStatus(from data: [String: Any]) {
        let timeInterval = data["time"] as? TimeInterval
        let nextTime = timeInterval.map { Date(timeIntervalSince1970: $0) }
        let enabled = data["enabled"] as? Bool ?? false
        let smartWake = data["smartWake"] as? Bool ?? false
        let window = data["smartWakeWindow"] as? Int ?? 30
        let name = data["name"] as? String ?? "Alarm"
        
        alarmStatus = WatchAlarmStatus(
            time: nextTime,
            enabled: enabled,
            smartWake: smartWake,
            window: window,
            name: name
        )
    }
    
    // MARK: - Utility Methods
    
    private func getCurrentBatteryLevel() -> Double {
        return Double(WKInterfaceDevice.current().batteryLevel)
    }
    
    private func getCurrentAppState() -> String {
        // Return current app state
        return isReceivingWakePattern ? "waking" : "active"
    }
    
    // MARK: - Public Interface
    
    func getConnectionStatus() -> [String: Any] {
        return [
            "isConnected": isConnected,
            "connectionQuality": connectionQuality.rawValue,
            "offlineMode": offlineMode,
            "lastSyncTime": lastSyncTime?.timeIntervalSince1970 ?? 0,
            "missedHeartbeats": missedHeartbeats
        ]
    }
    
    func forceSync() {
        if offlineMode && session.isReachable {
            disableOfflineMode()
        }
        requestLatestData()
    }
    
    deinit {
        heartbeatTimer?.invalidate()
    }
}

// MARK: - WCSessionDelegate
extension EnhancedWatchConnectivityManager: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async {
            self.isConnected = activationState == .activated
            
            if activationState == .activated {
                print("✅ Watch connectivity activated")
                self.updateConnectionQuality(.good)
                
                if self.offlineMode {
                    self.disableOfflineMode()
                }
                
                // Request initial data
                self.requestLatestData()
            } else {
                print("❌ Watch connectivity activation failed")
                if let error = error {
                    print("Error: \(error.localizedDescription)")
                }
                self.enableOfflineMode()
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            self.handleReceivedMessage(message)
        }
    }
    
    func session(
        _ session: WCSession,
        didReceiveMessage message: [String : Any],
        replyHandler: @escaping ([String : Any]) -> Void
    ) {
        DispatchQueue.main.async {
            self.handleReceivedMessage(message)
            replyHandler(["status": "received", "timestamp": Date().timeIntervalSince1970])
        }
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        DispatchQueue.main.async {
            self.handleDataUpdate(applicationContext)
            self.cacheReceivedData(applicationContext)
        }
    }
    
    private func handleReceivedMessage(_ message: [String: Any]) {
        guard let command = message["command"] as? String else {
            print("❌ Received message without command")
            return
        }
        
        print("📱 Received command: \(command)")
        
        switch command {
        case "wakePattern":
            handleWakePattern(from: message)
            
        case "stopPattern":
            stopWakePattern()
            
        case "sleepSummary", "alarmStatus":
            handleDataUpdate(message)
            cacheReceivedData(message)
            
        case "heartbeat":
            // Respond to heartbeat if reply handler is available
            break
            
        default:
            print("❓ Unknown command received: \(command)")
        }
    }
}

// MARK: - Supporting Types

struct OfflineAction: Codable {
    enum ActionType: String, Codable {
        case acknowledge
        case snooze
        case requestData
    }
    
    let type: ActionType
    let timestamp: Date
    let id: UUID
    
    init(type: ActionType, timestamp: Date) {
        self.type = type
        self.timestamp = timestamp
        self.id = UUID()
    }
}

// MARK: - Offline Storage

class WatchOfflineStorage {
    private let userDefaults = UserDefaults.standard
    
    private enum Keys {
        static let sleepSummary = "watchSleepSummary"
        static let alarmStatus = "watchAlarmStatus"
        static let lastSyncTime = "watchLastSyncTime"
        static let pendingActions = "watchPendingActions"
    }
    
    func cacheSleepSummary(_ data: [String: Any]) {
        userDefaults.set(data, forKey: Keys.sleepSummary)
    }
    
    func getCachedSleepSummary() -> WatchSleepSummary? {
        guard let data = userDefaults.object(forKey: Keys.sleepSummary) as? [String: Any] else {
            return nil
        }
        
        let duration = data["duration"] as? TimeInterval ?? 0
        let quality = data["quality"] as? Double ?? 0
        let qualityAvailable = data["qualityAvailable"] as? Bool ?? false
        let bedTime = (data["bedTime"] as? TimeInterval).map { Date(timeIntervalSince1970: $0) }
        let wakeTime = (data["wakeTime"] as? TimeInterval).map { Date(timeIntervalSince1970: $0) }
        
        return WatchSleepSummary(duration: duration, quality: quality, qualityAvailable: qualityAvailable, bedTime: bedTime, wakeTime: wakeTime)
    }
    
    func cacheAlarmStatus(_ data: [String: Any]) {
        userDefaults.set(data, forKey: Keys.alarmStatus)
    }
    
    func getCachedAlarmStatus() -> WatchAlarmStatus? {
        guard let data = userDefaults.object(forKey: Keys.alarmStatus) as? [String: Any] else {
            return nil
        }
        
        let timeInterval = data["time"] as? TimeInterval
        let nextTime = timeInterval.map { Date(timeIntervalSince1970: $0) }
        let enabled = data["enabled"] as? Bool ?? false
        let smartWake = data["smartWake"] as? Bool ?? false
        let window = data["smartWakeWindow"] as? Int ?? 30
        let name = data["name"] as? String ?? "Alarm"
        
        return WatchAlarmStatus(time: nextTime, enabled: enabled, smartWake: smartWake, window: window, name: name)
    }
    
    func updateLastSyncTime(_ date: Date) {
        userDefaults.set(date.timeIntervalSince1970, forKey: Keys.lastSyncTime)
    }
    
    func getLastSyncTime() -> Date? {
        let timestamp = userDefaults.double(forKey: Keys.lastSyncTime)
        return timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
    }
    
    func addPendingAction(_ action: OfflineAction) {
        var actions = getPendingActions()
        actions.append(action)
        
        if let data = try? JSONEncoder().encode(actions) {
            userDefaults.set(data, forKey: Keys.pendingActions)
        }
    }
    
    func getPendingActions() -> [OfflineAction] {
        guard let data = userDefaults.data(forKey: Keys.pendingActions),
              let actions = try? JSONDecoder().decode([OfflineAction].self, from: data) else {
            return []
        }
        return actions
    }
    
    func clearPendingActions() {
        userDefaults.removeObject(forKey: Keys.pendingActions)
    }
}
