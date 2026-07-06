import Foundation
import WatchKit

/// Manages haptic feedback patterns for alarm wake-up sequences on watchOS
class WatchHapticManager: ObservableObject {
    static let shared = WatchHapticManager()
    
    private var currentPattern: WakePatternData?
    private var patternTimer: Timer?
    private var pulseTimer: Timer?
    private var isPatternActive = false
    
    private init() {}
    
    deinit {
        stopAllPatterns()
    }
    
    /// Start playing a haptic wake-up pattern
    func startWakePattern(_ pattern: WakePatternData) {
        print("🔸 Starting haptic wake pattern: \(pattern.pattern.rawValue) at \(pattern.intensity) intensity")
        
        // Stop any existing pattern
        stopAllPatterns()
        
        currentPattern = pattern
        isPatternActive = true
        
        // Start the pattern progression
        startPatternProgression()
        
        // Set duration timer to automatically stop
        patternTimer = Timer.scheduledTimer(withTimeInterval: pattern.duration, repeats: false) { [weak self] _ in
            self?.stopAllPatterns()
        }
    }
    
    /// Stop the current wake pattern
    func stopAllPatterns() {
        print("🔹 Stopping all haptic patterns")
        
        isPatternActive = false
        currentPattern = nil
        
        patternTimer?.invalidate()
        patternTimer = nil
        
        pulseTimer?.invalidate()
        pulseTimer = nil
    }
    
    /// Start the progressive haptic pattern based on type and intensity
    private func startPatternProgression() {
        guard let pattern = currentPattern else { return }
        
        let pulseInterval = getPulseInterval(for: pattern.pattern)
        let hapticType = getHapticType(for: pattern.pattern, intensity: pattern.intensity)
        
        // Initial haptic
        playHapticFeedback(hapticType)
        
        // Schedule repeating pulses
        pulseTimer = Timer.scheduledTimer(withTimeInterval: pulseInterval, repeats: true) { [weak self] _ in
            guard let self = self, self.isPatternActive else { return }
            
            self.playHapticFeedback(hapticType)
            
            // Optional: Increase intensity over time for more aggressive wake-up
            if pattern.pattern == .strong {
                self.playDoubleHaptic(hapticType)
            }
        }
    }
    
    /// Get pulse interval based on pattern type
    private func getPulseInterval(for pattern: HapticPattern) -> TimeInterval {
        switch pattern {
        case .gentle:
            return 3.0  // Every 3 seconds - gentle, slow rhythm
        case .moderate:
            return 2.0  // Every 2 seconds - moderate pace
        case .strong:
            return 1.0  // Every 1 second - rapid, insistent
        }
    }
    
    /// Get appropriate haptic type based on pattern and intensity
    private func getHapticType(for pattern: HapticPattern, intensity: Double) -> WKHapticType {
        switch pattern {
        case .gentle:
            return intensity > 0.7 ? .notification : .directionUp
        case .moderate:
            return intensity > 0.7 ? .success : .notification
        case .strong:
            return intensity > 0.5 ? .failure : .success
        }
    }
    
    /// Play a single haptic feedback
    private func playHapticFeedback(_ type: WKHapticType) {
        WKInterfaceDevice.current().play(type)
    }
    
    /// Play double haptic for strong patterns
    private func playDoubleHaptic(_ type: WKHapticType) {
        playHapticFeedback(type)
        
        // Short delay then second pulse
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self, self.isPatternActive else { return }
            self.playHapticFeedback(type)
        }
    }
    
    /// Test haptic patterns (for debugging)
    func testHapticPattern(_ pattern: HapticPattern) {
        let testPattern = WakePatternData(
            pattern: pattern,
            intensity: 0.8,
            duration: 10.0  // 10 second test
        )
        startWakePattern(testPattern)
    }
    
    /// Quick haptic for user actions (button presses, etc.)
    func playActionFeedback() {
        WKInterfaceDevice.current().play(.click)
    }
    
    /// Success haptic for completing actions
    func playSuccessFeedback() {
        WKInterfaceDevice.current().play(.success)
    }
    
    /// Warning haptic for errors or alerts
    func playWarningFeedback() {
        WKInterfaceDevice.current().play(.failure)
    }
}