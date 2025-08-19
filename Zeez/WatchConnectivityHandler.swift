import Foundation
import WatchConnectivity
import os.log

/// Manages communication with the Apple Watch app
class WatchConnectivityHandler: NSObject, ObservableObject {
    static let shared = WatchConnectivityHandler()
    
    @Published var isWatchAvailable = false
    private var session: WCSession
    
    override private init() {
        self.session = WCSession.default
        super.init()
        
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }
    
    func sendWakePattern(_ pattern: HapticPattern, intensity: Double) {
        guard session.isReachable else { return }
        
        let message: [String: Any] = [
            "command": "wakePattern",
            "pattern": pattern.rawValue,
            "intensity": intensity
        ]
        
        session.sendMessage(message, replyHandler: nil) { error in
            ZeezLogger.error(ZeezLogger.network, "Error sending wake pattern to watch", error: error)
        }
    }
    
    func stopWakePattern() {
        guard session.isReachable else { return }
        
        session.sendMessage(
            ["command": "stopPattern"],
            replyHandler: nil,
            errorHandler: nil
        )
    }
    
    func updateAlarmContext(_ alarm: AlarmConfiguration) {
        guard let alarmTime = alarm.time else { return }
        
        let context: [String: Any] = [
            "type": "alarmUpdate",
            "alarmID": alarm.id?.uuidString ?? "",
            "time": alarmTime.timeIntervalSince1970,
            "enabled": alarm.enabled,
            "smartWake": alarm.smartWakeEnabled,
            "smartWakeWindow": alarm.smartWakeWindow
        ]
        
        do {
            try session.updateApplicationContext(context)
        } catch {
            ZeezLogger.error(ZeezLogger.network, "Error updating watch context", error: error)
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
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchAvailable = false
        }
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchAvailable = false
        }
        // Reactivate for future connections
        session.activate()
    }
    
    #if os(iOS)
    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchAvailable = session.isReachable
        }
    }
    
    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        handleWatchMessage(message, replyHandler: replyHandler)
    }
    #endif
    
    private func handleWatchMessage(
        _ message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        guard let command = message["command"] as? String else {
            replyHandler(["error": "Invalid command"])
            return
        }
        
        switch command {
        case "acknowledge":
            WakeUpProgressionManager.shared.acknowledgeWakeUp()
            replyHandler(["status": "success"])
            
        case "snooze":
            WakeUpProgressionManager.shared.snoozeWakeUp()
            replyHandler(["status": "success"])
            
        default:
            replyHandler(["error": "Unknown command"])
        }
    }
}
