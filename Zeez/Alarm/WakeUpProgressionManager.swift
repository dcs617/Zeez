import Foundation
import CoreData
import WatchConnectivity
import os.log

// MARK: - Wake-Up Communication Types

/// Wake-up progression message types (rename to avoid conflict)
enum WakeUpMessageType: String {
    case wakePattern = "wakePattern"
    case stopPattern = "stopPattern"
}



/// Manages the progressive wake-up sequence including haptic patterns and backup alarms
class WakeUpProgressionManager {
    static let shared = WakeUpProgressionManager()
    
    private var currentWakeSequence: WakeUpSequence?
    private var backupTimer: Timer?
    private let session = WCSession.default
    
    private init() {
        setupWatchConnectivity()
    }
    
    deinit {
        cleanup()
    }
    
    /// Clean up all resources
    private func cleanup() {
        stopCurrentSequence()
        // Additional cleanup if needed
    }
    
    /// Reset singleton state for testing
    func reset() {
        cleanup()
    }
    
    /// Starts a gentle wake-up sequence for a given alarm
    /// - Parameters:
    ///   - alarm: The alarm configuration
    ///   - session: Current sleep session
    ///   - completion: Called when user responds or backup triggers
    func startWakeSequence(
        for alarm: AlarmConfiguration,
        sleepSession: SleepSession,
        completion: @escaping (WakeUpResponse) -> Void
    ) {
        // Cancel any existing sequence
        stopCurrentSequence()
        
        let sequence = WakeUpSequence(
            alarm: alarm,
            sleepSession: sleepSession,
            startTime: Date()
        )
        
        currentWakeSequence = sequence
        
        // Start gentle progression
        startGentleProgression(sequence: sequence)
        
        // Set backup alarm
        setupBackupAlarm(for: sequence)
        
        // Monitor user response
        monitorUserResponse(sequence: sequence) { response in
            self.stopCurrentSequence()
            completion(response)
        }
    }
    
    /// Stops the current wake-up sequence
    func stopCurrentSequence() {
        currentWakeSequence = nil
        backupTimer?.invalidate()
        backupTimer = nil
        
        // Send stop command to watch
        if session.isReachable {
            let stopMessage = ["command": WakeUpMessageType.stopPattern.rawValue]
            session.sendMessage(stopMessage, replyHandler: nil) { error in
                ZeezLogger.error(ZeezLogger.alarm, "Error stopping wake sequence on watch", error: error)
            }
        }
    }
    
    /// User acknowledged the wake-up
    func acknowledgeWakeUp() {
        guard let sequence = currentWakeSequence else { return }
        sequence.completion?(.acknowledged)
        stopCurrentSequence()
    }
    
    /// User requested snooze
    func snoozeWakeUp() {
        guard let sequence = currentWakeSequence,
              let alarm = sequence.alarm,
              alarm.snoozeEnabled else { return }
        
        sequence.completion?(.snoozed)
        stopCurrentSequence()
        
        // Schedule new wake sequence after snooze duration
        let snoozeTime = Date().addingTimeInterval(Double(alarm.snoozeDuration) * 60)
        ZeezLogger.alarm.info("Alarm snoozed for \(alarm.snoozeDuration) minutes. Will resume at \(snoozeTime.formatted())")
        
        Timer.scheduledTimer(withTimeInterval: Double(alarm.snoozeDuration) * 60, repeats: false) { [weak self] _ in
            guard let self = self,
                  let alarm = sequence.alarm,
                  let session = sequence.sleepSession else { return }
            
            self.startWakeSequence(
                for: alarm,
                sleepSession: session
            ) { response in
                sequence.completion?(response)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else { return }
        session.activate()
    }
    
    private func startGentleProgression(sequence: WakeUpSequence) {
        guard session.isReachable else { return }
        
        // Send haptic pattern to watch using message instead of context
        let message: [String: Any] = [
            "command": WakeUpMessageType.wakePattern.rawValue,
            "pattern": sequence.currentPattern.rawValue,
            "intensity": sequence.currentIntensity,
            "duration": sequence.progressionDuration
        ]
        
        if session.isReachable {
            session.sendMessage(message, replyHandler: { reply in
                ZeezLogger.debug(ZeezLogger.alarm, "Watch confirmed wake pattern start: \(reply)")
            }) { error in
                ZeezLogger.error(ZeezLogger.alarm, "Error starting wake pattern on watch", error: error)
            }
        }
        
        // Schedule intensity increases
        scheduleProgressiveIntensity(for: sequence)
    }
    
    private func scheduleProgressiveIntensity(for sequence: WakeUpSequence) {
        // Increase intensity every minute
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] timer in
            guard let self = self,
                  let currentSequence = self.currentWakeSequence,
                  currentSequence.id == sequence.id else {
                timer.invalidate()
                return
            }
            
            sequence.increaseIntensity()
            
            if session.isReachable {
                // Update intensity on watch
                let updateMessage: [String: Any] = [
                    "command": WakeUpMessageType.wakePattern.rawValue,
                    "pattern": sequence.currentPattern.rawValue,
                    "intensity": sequence.currentIntensity,
                    "duration": sequence.progressionDuration
                ]
                
                session.sendMessage(updateMessage, replyHandler: nil) { error in
                    ZeezLogger.error(ZeezLogger.alarm, "Error updating wake pattern intensity", error: error)
                }
            }
        }
    }
    
    private func setupBackupAlarm(for sequence: WakeUpSequence) {
        let backupDelay = sequence.progressionDuration + 300 // 5 minutes after gentle progression
        
        backupTimer = Timer.scheduledTimer(withTimeInterval: backupDelay, repeats: false) { [weak self] _ in
            guard let self = self,
                  let currentSequence = self.currentWakeSequence,
                  currentSequence.id == sequence.id else { return }
            
            // Trigger full volume alarm
            sequence.completion?(.backupTriggered)
            
            // Send backup alarm command to watch
            if self.session.isReachable {
                do {
                    try self.session.updateApplicationContext([
                        "command": "triggerBackupAlarm"
                    ])
                } catch {
                    ZeezLogger.error(ZeezLogger.alarm, "Error triggering backup alarm on watch", error: error)
                }
            }
        }
    }
    
    private func monitorUserResponse(
        sequence: WakeUpSequence,
        completion: @escaping (WakeUpResponse) -> Void
    ) {
        sequence.completion = completion
    }
}

// MARK: - Supporting Types

/// Represents a single wake-up attempt
class WakeUpSequence {
    let id = UUID()
    let alarm: AlarmConfiguration?
    let sleepSession: SleepSession?
    let startTime: Date
    let progressionDuration: TimeInterval = 300 // 5 minutes
    
    var currentIntensity: Double = 0.2 // Start at 20%
    var currentPattern: HapticPattern = .gentle
    var completion: ((WakeUpResponse) -> Void)?
    
    init(alarm: AlarmConfiguration?, sleepSession: SleepSession?, startTime: Date) {
        self.alarm = alarm
        self.sleepSession = sleepSession
        self.startTime = startTime
    }
    
    func increaseIntensity() {
        currentIntensity = min(currentIntensity + 0.2, 1.0)
        
        // Update pattern based on intensity
        currentPattern = switch currentIntensity {
        case 0.0...0.3: .gentle
        case 0.3...0.6: .moderate
        default: .strong
        }
    }
}


/// Possible user responses to wake-up attempt
enum WakeUpResponse {
    case acknowledged
    case snoozed
    case backupTriggered
}
