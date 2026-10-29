import AVFoundation
import os.log

/// The slice of AVAudioSession the app uses. Production passes the shared session; tests pass
/// a fake that records what was asked of it (second-audit D2b).
protocol AudioSessioning: AnyObject {
    func setCategory(_ category: AVAudioSession.Category, mode: AVAudioSession.Mode,
                     options: AVAudioSession.CategoryOptions) throws
    func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws
}

extension AVAudioSession: AudioSessioning {}

/// The one owner of the app's audio session (2026-10-29). Nothing else may call
/// `setCategory` or `setActive` (`AudioSessionGuardTests`).
///
/// The alarm, a recording's microphone and the alarm-sound preview each need a different
/// category, and each used to set it themselves on the one shared session. Once recording was
/// reconnected that would have let a recording make the alarm quieter or cut it off: the
/// alarm's switch to playback silently stopped the recorder; the alarm's stop deactivated the
/// session under a recording in the background, so iOS suspended the app; a recording that
/// stopped deactivated the session under a ringing alarm; and a recorder that restarted while
/// the alarm rang switched it to play-and-record, which routes output to the earpiece.
///
/// So: the highest-priority holder's configuration is the session's. The alarm keeps exactly
/// the configuration it always had, and is applied first, before anything else is told. A
/// lower-priority client that asks while a higher one holds the session waits, untouched, and
/// gets the session back when the higher one lets go. The session is deactivated only when
/// nobody holds it.
final class AudioSessionCoordinator {
    static let shared = AudioSessionCoordinator()

    /// Ordered by priority: the alarm outranks everything.
    enum Client: Int, Comparable {
        case recording
        case preview
        case alarm

        static func < (lhs: Client, rhs: Client) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    /// Called when the recording's microphone input is taken by a higher-priority client
    /// (`false`) or handed back to it (`true`). On whatever thread caused the change.
    var recordingInputChanged: ((Bool) -> Void)?

    private let session: AudioSessioning
    private let lock = NSLock()
    private var holders: Set<Client> = []

    // Xcode 26's SDK renames .allowBluetooth → .allowBluetoothHFP (old name deprecated);
    // CI builds with Xcode 16.x, which only has .allowBluetooth.
    #if compiler(>=6.2)
    private static let bluetoothOption: AVAudioSession.CategoryOptions = .allowBluetoothHFP
    #else
    private static let bluetoothOption: AVAudioSession.CategoryOptions = .allowBluetooth
    #endif

    init(session: AudioSessioning = AVAudioSession.sharedInstance()) {
        self.session = session
    }

    /// Who holds the session now. For tests and logs.
    var currentHolders: Set<Client> {
        lock.lock(); defer { lock.unlock() }
        return holders
    }

    /// Whether the recording's input is live: it holds the session and nothing outranks it.
    var recordingHasInput: Bool {
        lock.lock(); defer { lock.unlock() }
        return holders.max() == .recording
    }

    /// Takes the session for `client`. If something of higher priority holds it, the client
    /// waits and the session is left alone. Throws when the session refuses the configuration,
    /// and the client then holds nothing.
    func acquire(_ client: Client) throws {
        lock.lock()
        let previousTop = holders.max()
        holders.insert(client)
        let isTop = holders.max() == client
        lock.unlock()

        guard isTop else {
            ZeezLogger.info(ZeezLogger.app, "Audio session: \(client) waits for a higher-priority client")
            return
        }

        do {
            try apply(client)
        } catch {
            lock.lock(); holders.remove(client); lock.unlock()
            throw error
        }

        if previousTop == .recording, client != .recording {
            recordingInputChanged?(false)
        }
    }

    /// Lets go of the session. A lower-priority client still holding it gets it back;
    /// otherwise the session is deactivated so audio the app interrupted can resume.
    func release(_ client: Client) {
        lock.lock()
        guard holders.contains(client) else {
            lock.unlock()
            return
        }
        let wasTop = holders.max() == client
        holders.remove(client)
        let next = holders.max()
        lock.unlock()

        guard wasTop else { return }

        if let next {
            do {
                try apply(next)
                if next == .recording {
                    recordingInputChanged?(true)
                }
            } catch {
                ZeezLogger.error(ZeezLogger.app, "Audio session: could not hand back to \(next)", error: error)
            }
        } else {
            do {
                try session.setActive(false, options: [.notifyOthersOnDeactivation])
            } catch {
                ZeezLogger.error(ZeezLogger.app, "Audio session: error deactivating", error: error)
            }
        }
    }

    private func apply(_ client: Client) throws {
        switch client {
        case .alarm:
            // Exactly what the alarm always set: loud, over other audio, and to Bluetooth.
            try session.setCategory(.playback, mode: .default, options: [.duckOthers, Self.bluetoothOption])
        case .preview:
            try session.setCategory(.playback, mode: .default, options: [])
        case .recording:
            // Metering only. Mixable, so other apps' audio neither stops it nor is stopped by it.
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.mixWithOthers])
        }
        try session.setActive(true, options: [])
    }
}
