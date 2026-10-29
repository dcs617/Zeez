import AVFoundation

// The audio session itself belongs to `AudioSessionCoordinator` (`AudioSessioning`).

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
