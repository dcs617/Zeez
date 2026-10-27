import AVFoundation

/// The slice of AVAudioSession the alarm's looped audio uses (second-audit D2b).
///
/// Production injects the shared session; tests inject a fake that records what was
/// asked of it, so stopping can be checked for `.notifyOthersOnDeactivation`.
protocol AlarmAudioSessioning: AnyObject {
    func setCategory(_ category: AVAudioSession.Category, mode: AVAudioSession.Mode,
                     options: AVAudioSession.CategoryOptions) throws
    func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws
}

extension AVAudioSession: AlarmAudioSessioning {}

/// The slice of AVAudioPlayer the alarm's looped audio uses.
protocol AlarmAudioPlaying: AnyObject {
    var numberOfLoops: Int { get set }
    var volume: Float { get set }
    var isPlaying: Bool { get }
    @discardableResult func prepareToPlay() -> Bool
    @discardableResult func play() -> Bool
    func stop()
}

extension AVAudioPlayer: AlarmAudioPlaying {}

/// Makes the alarm's players, so tests can hand out ones that fail, stall or stop —
/// the paths a device pass can never drive on purpose.
protocol AlarmAudioPlayerMaking {
    func makePlayer(contentsOf url: URL) throws -> AlarmAudioPlaying
}

struct AVAudioPlayerMaker: AlarmAudioPlayerMaking {
    func makePlayer(contentsOf url: URL) throws -> AlarmAudioPlaying {
        try AVAudioPlayer(contentsOf: url)
    }
}
