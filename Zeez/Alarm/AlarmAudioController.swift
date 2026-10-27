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
        /// Alarm_Classic at a fixed volume, when the chosen sound will not play.
        case fallback
    }
    private var source: Source?
    private var requestedVolume: Float = 1.0
    private static let fallbackName = "Alarm_Classic"
    private static let fallbackVolume: Float = 0.8

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
            let playerVolume: Float
            switch source {
            case .bundled(let name, let fileExtension):
                guard let bundled = Bundle.main.url(forResource: name, withExtension: fileExtension) else {
                    ZeezLogger.error(ZeezLogger.alarm, "Missing bundled audio \(name).\(fileExtension)")
                    fallBack(from: source)
                    return
                }
                url = bundled
                playerVolume = normalizeVolume(volume, for: name)
            case .file(let fileURL):
                url = fileURL
                playerVolume = normalizeVolume(volume, for: fileURL.lastPathComponent)
            case .fallback:
                guard let classic = Bundle.main.url(forResource: Self.fallbackName, withExtension: "caf") else {
                    fallBack(from: source)
                    return
                }
                url = classic
                playerVolume = Self.fallbackVolume
            }

            let p = try players.makePlayer(contentsOf: url)
            p.numberOfLoops = -1
            p.volume = playerVolume
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
            case .fallback:
                ZeezLogger.info(ZeezLogger.alarm, "🎵 Started fallback bundled sound")
            }
        } catch {
            ZeezLogger.error(ZeezLogger.alarm, "AlarmAudioController startLooping error", error: error)
            fallBack(from: source)
        }
    }

    /// A sound that will not play falls back to Alarm_Classic, which the watchdog then keeps
    /// alive like any loop; Alarm_Classic falls back to the repeating system sound.
    private func fallBack(from source: Source) {
        if case .fallback = source {
            ZeezLogger.error(ZeezLogger.alarm, "Fallback bundled sound will not play")
            startSystemSoundFallback()
        } else {
            ZeezLogger.info(ZeezLogger.alarm, "🎵 Using fallback sound")
            play(.fallback, volume: Self.fallbackVolume)
        }
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
    /// A loop that stopped unexpectedly is restarted, up to `maxRetries` failed checks in a
    /// row; then the alarm falls back to another sound rather than keep restarting a file that
    /// will not play. A restart's `stop()` zeroes the count, so the restart carries it across.
    /// The fallback sound gets its own `maxRetries` before the system sound, which has no
    /// player to watch.
    func checkAudioHealth() {
        guard isPlaying, let source else { return }

        if let player, player.isPlaying {
            retryCount = 0
            return
        }

        // Audio stopped unexpectedly, attempt to restart
        retryCount += 1
        if retryCount <= maxRetries {
            ZeezLogger.info(ZeezLogger.alarm, "⚠️ Audio watchdog: restarting audio (attempt \(retryCount))")
            let failedChecks = retryCount
            stop()
            retryCount = failedChecks
            play(source, volume: requestedVolume)
        } else {
            ZeezLogger.error(ZeezLogger.alarm, "Audio watchdog: max retries reached, falling back")
            // Retire the watchdog and the dead loop first. Left running, every later check
            // would fall back again, and each fallback to the system sound would add another
            // beep timer. A fallback sound that plays starts a watchdog of its own.
            watchdogTimer?.invalidate()
            watchdogTimer = nil
            player?.stop()
            player = nil
            self.source = nil
            retryCount = 0
            fallBack(from: source)
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
