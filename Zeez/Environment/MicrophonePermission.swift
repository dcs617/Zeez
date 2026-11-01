import AVFoundation

/// Whether Zeez may use the microphone. A recording needs it (decision 2026-11-01): noise is
/// the only thing a phone on the nightstand measures, and a live microphone is what keeps the
/// app running overnight. Production asks `AVAudioApplication`; tests pass a fake.
protocol MicrophonePermission {
    var isGranted: Bool { get }
    /// Asks the user when they have not been asked yet. Answers on any thread.
    func request(_ completion: @escaping (Bool) -> Void)
}

struct LiveMicrophonePermission: MicrophonePermission {
    var isGranted: Bool {
        AVAudioApplication.shared.recordPermission == .granted
    }

    func request(_ completion: @escaping (Bool) -> Void) {
        AVAudioApplication.requestRecordPermission(completionHandler: completion)
    }
}
