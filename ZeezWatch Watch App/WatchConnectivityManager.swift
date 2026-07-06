import Foundation
import WatchConnectivity
import SwiftUI
import WatchKit

/// Enhanced watch connectivity manager with improved reliability and offline support
class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
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
            "batteryLevel": WKInterfaceDevice.current().batteryLevel,
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
        loadOfflineData()
        hapticManager.playWarningFeedback()
    }
    
    private func disableOfflineMode() {
        offlineMode = false
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
    
    /// Request latest data from iPhone
    func requestLatestData() {
        guard session.isReachable else { return }
        
        let message = ["command": WatchMessageType.requestData.rawValue]
        session.sendMessage(message, replyHandler: { [weak self] reply in
            DispatchQueue.main.async {
                self?.handleDataUpdate(reply)
            }
        }) { error in
            print("Error requesting data: \(error.localizedDescription)")
        }
    }
    
    /// Send alarm acknowledgment to iPhone
    func acknowledgeAlarm() {
        guard session.isReachable else { return }
        
        // Play success haptic feedback
        hapticManager.playSuccessFeedback()
        
        let message = ["command": WatchMessageType.acknowledge.rawValue]
        session.sendMessage(message, replyHandler: nil) { error in
            print("Error acknowledging alarm: \(error.localizedDescription)")
        }
        
        // Stop any current wake pattern
        stopWakePattern()
    }
    
    /// Send snooze command to iPhone
    func snoozeAlarm() {
        guard session.isReachable else { return }
        
        // Play action haptic feedback
        hapticManager.playActionFeedback()
        
        let message = ["command": WatchMessageType.snooze.rawValue]
        session.sendMessage(message, replyHandler: nil) { error in
            print("Error snoozing alarm: \(error.localizedDescription)")
        }
        
        // Stop any current wake pattern
        stopWakePattern()
    }
    
    /// Stop current wake pattern
    private func stopWakePattern() {
        isReceivingWakePattern = false
        currentWakePattern = nil
        
        // Stop haptic patterns
        hapticManager.stopAllPatterns()
    }
    
    /// Handle data updates from iPhone
    private func handleDataUpdate(_ data: [String: Any]) {
        if let sleepData = data["sleepSummary"] as? [String: Any] {
            updateSleepSummary(from: sleepData)
        }
        
        if let alarmData = data["alarmStatus"] as? [String: Any] {
            updateAlarmStatus(from: alarmData)
        }
    }
    
    /// Update sleep summary from received data
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
    
    /// Update alarm status from received data
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
    
    /// Handle wake pattern from iPhone
    private func handleWakePattern(from data: [String: Any]) {
        guard let patternString = data["pattern"] as? String,
              let pattern = HapticPattern(rawValue: patternString),
              let intensity = data["intensity"] as? Double else {
            return
        }
        
        let duration = data["duration"] as? TimeInterval ?? 30
        let wakePattern = WakePatternData(pattern: pattern, intensity: intensity, duration: duration)
        
        currentWakePattern = wakePattern
        isReceivingWakePattern = true
        
        // Start haptic feedback using the haptic manager
        hapticManager.startWakePattern(wakePattern)
    }
}

// MARK: - WCSessionDelegate
extension WatchConnectivityManager: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async {
            self.isConnected = activationState == .activated
            if self.isConnected {
                self.requestLatestData()
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
            replyHandler(["status": "received"])
        }
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        DispatchQueue.main.async {
            self.handleDataUpdate(applicationContext)
        }
    }
    
    private func handleReceivedMessage(_ message: [String: Any]) {
        guard let command = message["command"] as? String else { return }
        
        switch command {
        case WatchMessageType.wakePattern.rawValue:
            handleWakePattern(from: message)
        case WatchMessageType.stopPattern.rawValue:
            stopWakePattern()
        case WatchMessageType.sleepSummary.rawValue,
             WatchMessageType.alarmStatus.rawValue:
            handleDataUpdate(message)
        default:
            break
        }
    }
    
    // MARK: - Utility Methods
    
    private func getCurrentAppState() -> String {
        return isReceivingWakePattern ? "waking" : "active"
    }
}

// MARK: - Simple Message Queue for Watch

class WatchLocalMessageQueue {
    private var pendingCount = 0
    
    func getPendingCount() -> Int {
        return pendingCount
    }
}
