import Foundation
import AVFoundation
import AudioToolbox
import os.log

/// Foreground-only long/looped audio for the alarm once the user opens the app.
final class AlarmAudioController {
    static let shared = AlarmAudioController()

    private let session: AlarmAudioSessioning
    private let players: AlarmAudioPlayerMaking
    private var player: AlarmAudioPlaying?
    private(set) var isPlaying = false
    private var watchdogTimer: Timer?
    private var fallbackTimer: Timer?
    private var retryCount = 0
    private let maxRetries = 5

    /// What the watchdog restarts: the loop that is meant to be playing.
    private enum Source {
        case bundled(name: String, fileExtension: String)
        case file(URL)
    }
    private var source: Source?
    private var requestedVolume: Float = 1.0

    // Xcode 26's SDK renames .allowBluetooth → .allowBluetoothHFP (old name deprecated);
    // CI builds with Xcode 16.x, which only has .allowBluetooth.
    #if compiler(>=6.2)
    private let bluetoothOption: AVAudioSession.CategoryOptions = .allowBluetoothHFP
    #else
    private let bluetoothOption: AVAudioSession.CategoryOptions = .allowBluetooth
    #endif

    /// Tests inject a fake session + player factory; production uses the real ones.
    init(session: AlarmAudioSessioning = AVAudioSession.sharedInstance(),
         players: AlarmAudioPlayerMaking = AVAudioPlayerMaker()) {
        self.session = session
        self.players = players
    }

    /// Whether the alarm has fallen back to the repeating system beep, the last resort
    /// when no file will play.
    var isUsingSystemSoundFallback: Bool { fallbackTimer != nil }

    /// Play and loop a bundled file (e.g., "Zeez_Long_Default.caf").
    func startLooping(bundledName: String, fileExtension: String = "caf", volume: Float = 1.0) {
        stop()
        play(.bundled(name: bundledName, fileExtension: fileExtension), volume: volume)
    }

    /// Start looping with a file URL (for user-imported sounds)
    func startLooping(fileURL: URL, volume: Float = 1.0) {
        stop()
        play(.file(fileURL), volume: volume)
    }

    private func play(_ source: Source, volume: Float) {
        do {
            try session.setCategory(.playback, mode: .default, options: [.duckOthers, bluetoothOption])
            try session.setActive(true, options: [])

            let url: URL
            let volumeKey: String
            switch source {
            case .bundled(let name, let fileExtension):
                guard let bundled = Bundle.main.url(forResource: name, withExtension: fileExtension) else {
                    ZeezLogger.error(ZeezLogger.alarm, "Missing bundled audio \(name).\(fileExtension)")
                    // Fallback to a system sound URL if available
                    fallbackToSystemSound()
                    return
                }
                url = bundled
                volumeKey = name
            case .file(let fileURL):
                url = fileURL
                volumeKey = fileURL.lastPathComponent
            }

            let p = try players.makePlayer(contentsOf: url)
            p.numberOfLoops = -1
            p.volume = normalizeVolume(volume, for: volumeKey)
            p.prepareToPlay()
            p.play()
            player = p
            isPlaying = true
            self.source = source
            requestedVolume = volume
            startWatchdog()

            switch source {
            case .bundled(let name, _):
                ZeezLogger.info(ZeezLogger.alarm, "🔊 Started looping alarm audio: \(name)")
            case .file(let fileURL):
                // User file names are personal content — debug builds only.
                ZeezLogger.info(ZeezLogger.alarm, "🔊 Started looping user audio")
                ZeezLogger.debug(ZeezLogger.alarm, "   User audio file: \(fileURL.lastPathComponent)")
            }
        } catch {
            ZeezLogger.error(ZeezLogger.alarm, "AlarmAudioController startLooping error", error: error)
            fallbackToSystemSound()
        }
    }

    private func fallbackToSystemSound() {
        ZeezLogger.info(ZeezLogger.alarm, "🎵 Using fallback system beep")

        // Try to use a bundled fallback sound first
        if let fallbackURL = Bundle.main.url(forResource: "Alarm_Classic", withExtension: "caf") {
            do {
                let p = try players.makePlayer(contentsOf: fallbackURL)
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
        source = nil
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
        return canPlay(fileURL: url)
    }

    /// Test if a user sound file is playable
    func canPlay(fileURL: URL) -> Bool {
        do {
            let _ = try players.makePlayer(contentsOf: fileURL)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Watchdog for audio reliability

    private func startWatchdog() {
        watchdogTimer?.invalidate()
        watchdogTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkAudioHealth()
        }
    }

    /// The watchdog's check, every two seconds while a loop plays. Internal so tests can run
    /// it directly rather than wait on the timer.
    ///
    /// A loop that stopped unexpectedly is restarted. The `maxRetries` cap never trips:
    /// each restart's `stop()` zeroes the count.
    func checkAudioHealth() {
        guard isPlaying, let source else { return }

        if let player, player.isPlaying {
            // Audio is playing correctly
            return
        }

        // Audio stopped unexpectedly, attempt to restart
        retryCount += 1
        if retryCount <= maxRetries {
            ZeezLogger.info(ZeezLogger.alarm, "⚠️ Audio watchdog: restarting audio (attempt \(retryCount))")
            stop()
            play(source, volume: requestedVolume)
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
