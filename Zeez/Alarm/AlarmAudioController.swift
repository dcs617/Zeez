import Foundation
import AVFoundation
import AudioToolbox
import os.log

/// Foreground-only long/looped audio for the alarm once the user opens the app.
final class AlarmAudioController {
    static let shared = AlarmAudioController()

    private let session = AVAudioSession.sharedInstance()
    private var player: AVAudioPlayer?
    private(set) var isPlaying = false
    private var watchdogTimer: Timer?
    private var fallbackTimer: Timer?
    private var retryCount = 0
    private let maxRetries = 5

    private init() {}

    /// Play and loop a bundled file (e.g., "Zeez_Long_Default.caf").
    func startLooping(bundledName: String, fileExtension: String = "caf", volume: Float = 1.0) {
        stop()
        do {
            try session.setCategory(.playback, mode: .default, options: [.duckOthers, .allowBluetoothHFP])
            try session.setActive(true)
            guard let url = Bundle.main.url(forResource: bundledName, withExtension: fileExtension) else {
                ZeezLogger.error(ZeezLogger.alarm, "Missing bundled audio \(bundledName).\(fileExtension)")
                // Fallback to a system sound URL if available
                fallbackToSystemSound()
                return
            }
            let p = try AVAudioPlayer(contentsOf: url)
            p.numberOfLoops = -1
            p.volume = normalizeVolume(volume, for: bundledName)
            p.prepareToPlay()
            p.play()
            player = p
            isPlaying = true
            retryCount = 0
            startWatchdog(bundledName: bundledName, fileExtension: fileExtension, volume: volume)
            ZeezLogger.info(ZeezLogger.alarm, "🔊 Started looping alarm audio: \(bundledName)")
        } catch {
            ZeezLogger.error(ZeezLogger.alarm, "AlarmAudioController startLooping error", error: error)
            fallbackToSystemSound()
        }
    }
    
    /// Start looping with a file URL (for user-imported sounds)
    func startLooping(fileURL: URL, volume: Float = 1.0) {
        stop()
        do {
            try session.setCategory(.playback, mode: .default, options: [.duckOthers, .allowBluetoothHFP])
            try session.setActive(true)
            
            let p = try AVAudioPlayer(contentsOf: fileURL)
            p.numberOfLoops = -1
            p.volume = normalizeVolume(volume, for: fileURL.lastPathComponent)
            p.prepareToPlay()
            p.play()
            player = p
            isPlaying = true
            retryCount = 0
            startWatchdog(fileURL: fileURL, volume: volume)
            // User file names are personal content — debug builds only.
            ZeezLogger.info(ZeezLogger.alarm, "🔊 Started looping user audio")
            ZeezLogger.debug(ZeezLogger.alarm, "   User audio file: \(fileURL.lastPathComponent)")
        } catch {
            ZeezLogger.error(ZeezLogger.alarm, "AlarmAudioController startLooping (URL) error", error: error)
            fallbackToSystemSound()
        }
    }
    
    private func fallbackToSystemSound() {
        ZeezLogger.info(ZeezLogger.alarm, "🎵 Using fallback system beep")
        
        // Try to use a bundled fallback sound first
        if let fallbackURL = Bundle.main.url(forResource: "Alarm_Classic", withExtension: "caf") {
            do {
                let p = try AVAudioPlayer(contentsOf: fallbackURL)
                p.numberOfLoops = -1
                p.volume = 0.8
                p.prepareToPlay()
                p.play()
                player = p
                isPlaying = true
                ZeezLogger.info(ZeezLogger.alarm, "🎵 Started fallback bundled sound")
                return
            } catch {
                ZeezLogger.error(ZeezLogger.alarm, "Failed to play fallback bundled sound", error: error)
            }
        }
        
        // Final fallback: repeating system sound
        startSystemSoundFallback()
    }
    
    private func startSystemSoundFallback() {
        // Use a timer to create a repeating beep pattern
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            guard self.isPlaying else { return }
            AudioServicesPlaySystemSound(SystemSoundID(1005)) // System alert sound
        }
        
        fallbackTimer = timer
        isPlaying = true
        ZeezLogger.info(ZeezLogger.alarm, "🔊 Started system sound fallback timer")
    }

    func stop() {
        isPlaying = false
        player?.stop()
        player = nil
        retryCount = 0
        
        // Stop watchdog timer
        watchdogTimer?.invalidate()
        watchdogTimer = nil
        
        fallbackTimer?.invalidate()
        fallbackTimer = nil
        
        do {
            try session.setActive(false, options: [.notifyOthersOnDeactivation])
            ZeezLogger.info(ZeezLogger.alarm, "🔇 Stopped alarm audio")
        } catch { 
            ZeezLogger.error(ZeezLogger.alarm, "Error deactivating audio session", error: error)
        }
    }
    
    /// Test if a sound file is playable
    func canPlay(bundledName: String, fileExtension: String = "caf") -> Bool {
        guard let url = Bundle.main.url(forResource: bundledName, withExtension: fileExtension) else {
            return false
        }
        
        do {
            let _ = try AVAudioPlayer(contentsOf: url)
            return true
        } catch {
            return false
        }
    }
    
    /// Test if a user sound file is playable
    func canPlay(fileURL: URL) -> Bool {
        do {
            let _ = try AVAudioPlayer(contentsOf: fileURL)
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Watchdog for audio reliability
    
    private func startWatchdog(bundledName: String, fileExtension: String = "caf", volume: Float = 1.0) {
        watchdogTimer?.invalidate()
        watchdogTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkAudioStatus(bundledName: bundledName, fileExtension: fileExtension, volume: volume)
        }
    }
    
    private func startWatchdog(fileURL: URL, volume: Float = 1.0) {
        watchdogTimer?.invalidate()
        watchdogTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkAudioStatus(fileURL: fileURL, volume: volume)
        }
    }
    
    private func checkAudioStatus(bundledName: String, fileExtension: String, volume: Float) {
        guard isPlaying else { return }
        
        if let player = player, player.isPlaying {
            // Audio is playing correctly
            return
        }
        
        // Audio stopped unexpectedly, attempt to restart
        retryCount += 1
        if retryCount <= maxRetries {
            ZeezLogger.info(ZeezLogger.alarm, "⚠️ Audio watchdog: restarting audio (attempt \(retryCount))")
            startLooping(bundledName: bundledName, fileExtension: fileExtension, volume: volume)
        } else {
            ZeezLogger.error(ZeezLogger.alarm, "Audio watchdog: max retries reached, falling back to system sound")
            fallbackToSystemSound()
        }
    }
    
    private func checkAudioStatus(fileURL: URL, volume: Float) {
        guard isPlaying else { return }
        
        if let player = player, player.isPlaying {
            // Audio is playing correctly
            return
        }
        
        // Audio stopped unexpectedly, attempt to restart
        retryCount += 1
        if retryCount <= maxRetries {
            ZeezLogger.info(ZeezLogger.alarm, "⚠️ Audio watchdog: restarting user audio (attempt \(retryCount))")
            startLooping(fileURL: fileURL, volume: volume)
        } else {
            ZeezLogger.error(ZeezLogger.alarm, "Audio watchdog: max retries reached, falling back to system sound")
            fallbackToSystemSound()
        }
    }
    
    // MARK: - Audio Normalization
    
    /// Normalize volume levels for different sound files to ensure consistent loudness
    private func normalizeVolume(_ requestedVolume: Float, for fileName: String) -> Float {
        // Base volume adjustments for different sound files to achieve consistent perceived loudness
        let soundAdjustments: [String: Float] = [
            "Alarm_Classic.caf": 0.9,    // Slightly reduce if it's naturally loud
            "Alarm_Honk.caf": 0.8,       // Reduce if very aggressive
            "Alarm_Horn.caf": 0.85,      // Moderate reduction
            "Zeez_Long_Default.caf": 0.9  // Default long sound
        ]
        
        // Get the adjustment factor for this sound, default to 1.0
        let adjustment = soundAdjustments[fileName] ?? 1.0
        
        // Apply the adjustment while respecting the user's volume preference
        let normalizedVolume = requestedVolume * adjustment
        
        // Ensure volume stays within bounds and add gentle attack curve
        let clampedVolume = max(0.1, min(1.0, normalizedVolume))
        
        ZeezLogger.debug(ZeezLogger.alarm, "🔊 Volume normalized for \(fileName): \(requestedVolume) -> \(clampedVolume) (adjustment: \(adjustment))")
        
        return clampedVolume
    }
}