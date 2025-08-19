import SwiftUI
import Combine
import os.log

/// Manages active alarm state and user interactions
class AlarmStateManager: ObservableObject {
    static let shared = AlarmStateManager()
    
    @Published var activeAlarm: AlarmConfiguration?
    @Published var isWaking = false
    @Published var remainingSnoozeTime: TimeInterval?
    
    private var snoozeTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupNotificationHandling()
    }
    
    func startWaking(alarm: AlarmConfiguration) {
        activeAlarm = alarm
        isWaking = true
        remainingSnoozeTime = nil
    }
    
    func stopWaking() {
        activeAlarm = nil
        isWaking = false
        remainingSnoozeTime = nil
        snoozeTimer?.invalidate()
        snoozeTimer = nil
    }
    
    func snooze() {
        guard let alarm = activeAlarm,
              alarm.snoozeEnabled else { return }
        
        isWaking = false
        remainingSnoozeTime = TimeInterval(alarm.snoozeDuration * 60)
        
        // Start snooze countdown
        snoozeTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if let remaining = self.remainingSnoozeTime {
                if remaining > 0 {
                    self.remainingSnoozeTime = remaining - 1
                } else {
                    self.startWaking(alarm: alarm)
                    self.snoozeTimer?.invalidate()
                    self.snoozeTimer = nil
                }
            }
        }
    }
    
    private func setupNotificationHandling() {
        NotificationCenter.default
            .publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.updateSnoozeTimeIfNeeded()
            }
            .store(in: &cancellables)
    }
    
    private func updateSnoozeTimeIfNeeded() {
        guard let alarm = activeAlarm,
              let snoozeStart = alarm.modifiedAt,
              let remaining = remainingSnoozeTime else { return }
        
        let elapsed = Date().timeIntervalSince(snoozeStart)
        let updatedRemaining = max(0, remaining - elapsed)
        
        if updatedRemaining <= 0 {
            startWaking(alarm: alarm)
        } else {
            remainingSnoozeTime = updatedRemaining
        }
    }
}
