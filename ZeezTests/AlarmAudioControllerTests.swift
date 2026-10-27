import Testing
import Foundation
import AVFoundation
@testable import Zeez

/// Records what the alarm audio asked of the audio session (second-audit D2b).
final class FakeAudioSession: AlarmAudioSessioning, @unchecked Sendable {
    enum Call: Equatable {
        case setCategory(AVAudioSession.Category, AVAudioSession.CategoryOptions)
        case setActive(Bool, AVAudioSession.SetActiveOptions)
    }

    private let lock = NSLock()
    private var storage: [Call] = []

    var calls: [Call] {
        lock.lock(); defer { lock.unlock() }
        return storage
    }

    func setCategory(_ category: AVAudioSession.Category, mode: AVAudioSession.Mode,
                     options: AVAudioSession.CategoryOptions) throws {
        lock.lock(); storage.append(.setCategory(category, options)); lock.unlock()
    }

    func setActive(_ active: Bool, options: AVAudioSession.SetActiveOptions) throws {
        lock.lock(); storage.append(.setActive(active, options)); lock.unlock()
    }
}

/// A player that plays when told to, unless it stalls. Tests interrupt it to do what an
/// interruption or a route change does to a real one.
final class FakeAudioPlayer: AlarmAudioPlaying, @unchecked Sendable {
    let fileName: String
    private let stalls: Bool
    private let lock = NSLock()
    private var loops = 0
    private var level: Float = 1
    private var playing = false
    private var stopped = false

    init(fileName: String, stalls: Bool) {
        self.fileName = fileName
        self.stalls = stalls
    }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock(); defer { lock.unlock() }
        return body()
    }

    var numberOfLoops: Int {
        get { locked { loops } }
        set { locked { loops = newValue } }
    }

    var volume: Float {
        get { locked { level } }
        set { locked { level = newValue } }
    }

    var isPlaying: Bool { locked { playing } }
    var wasStopped: Bool { locked { stopped } }

    func prepareToPlay() -> Bool { true }

    func play() -> Bool {
        locked { playing = !stalls }
        return !stalls
    }

    func stop() {
        locked { playing = false; stopped = true }
    }

    func interrupt() { locked { playing = false } }
    func resume() { locked { playing = true } }
}

/// Hands out fake players by file name: some fail to load, some load but never play.
final class FakeAudioPlayerFactory: AlarmAudioPlayerMaking, @unchecked Sendable {
    private let failing: Set<String>
    private let stalling: Set<String>
    private let lock = NSLock()
    private var attemptStorage: [String] = []
    private var playerStorage: [FakeAudioPlayer] = []

    init(failing: Set<String> = [], stalling: Set<String> = []) {
        self.failing = failing
        self.stalling = stalling
    }

    /// Every file a player was asked for, in order, including the ones that failed.
    var attempts: [String] {
        lock.lock(); defer { lock.unlock() }
        return attemptStorage
    }

    /// The players actually made, in order.
    var players: [FakeAudioPlayer] {
        lock.lock(); defer { lock.unlock() }
        return playerStorage
    }

    func makePlayer(contentsOf url: URL) throws -> AlarmAudioPlaying {
        let name = url.lastPathComponent
        lock.lock(); defer { lock.unlock() }
        attemptStorage.append(name)
        if failing.contains(name) {
            throw CocoaError(.fileReadCorruptFile)
        }
        let player = FakeAudioPlayer(fileName: name, stalls: stalling.contains(name))
        playerStorage.append(player)
        return player
    }
}

/// The alarm's last mile once the app is open (second-audit D2b). A device pass hears the
/// happy path; it cannot make a loop die on cue, so the watchdog, the fallbacks and the
/// session hand-back on stop are pinned here. The watchdog's timer is not faked: tests
/// call `checkAudioHealth()`, the check it runs every two seconds.
@Suite("Alarm audio controller")
struct AlarmAudioControllerTests {

    private static let long = "Zeez_Long_Default"
    private static let longFile = "Zeez_Long_Default.caf"
    private static let classicFile = "Alarm_Classic.caf"

    private func start(_ factory: FakeAudioPlayerFactory,
                       session: FakeAudioSession = FakeAudioSession()) -> AlarmAudioController {
        let controller = AlarmAudioController(session: session, players: factory)
        controller.startLooping(bundledName: Self.long)
        return controller
    }

    // MARK: - Watchdog

    @Test("The watchdog leaves a loop that is still playing alone")
    func healthyLoopIsLeftAlone() {
        let factory = FakeAudioPlayerFactory()
        let controller = start(factory)

        controller.checkAudioHealth()

        #expect(factory.attempts == [Self.longFile])
        #expect(factory.players.first?.isPlaying == true)
    }

    @Test("The watchdog restarts a loop that stopped, on the same file")
    func stoppedLoopIsRestarted() throws {
        let factory = FakeAudioPlayerFactory()
        let controller = start(factory)

        try #require(factory.players.first).interrupt()
        controller.checkAudioHealth()

        #expect(factory.attempts == [Self.longFile, Self.longFile])
        #expect(factory.players.last?.isPlaying == true)
        #expect(factory.players.last?.numberOfLoops == -1)
        #expect(controller.isPlaying)
    }

    // MARK: - Fallbacks

    @Test("When the chosen file will not load, the classic sound plays instead")
    func unloadableFileFallsBackToClassic() {
        let factory = FakeAudioPlayerFactory(failing: [Self.longFile])
        let controller = start(factory)

        #expect(factory.attempts == [Self.longFile, Self.classicFile])
        #expect(factory.players.last?.fileName == Self.classicFile)
        #expect(factory.players.last?.isPlaying == true)
        #expect(controller.isPlaying)
        #expect(!controller.isUsingSystemSoundFallback)
    }

    /// Settings' audio test asks for "test_sound", which the app does not bundle.
    @Test("A sound missing from the bundle falls back to the classic sound")
    func missingFileFallsBackToClassic() {
        let factory = FakeAudioPlayerFactory()
        let controller = AlarmAudioController(session: FakeAudioSession(), players: factory)

        controller.startLooping(bundledName: "test_sound")

        #expect(factory.attempts == [Self.classicFile])
        #expect(factory.players.last?.isPlaying == true)
        #expect(controller.isPlaying)
    }

    @Test("With no file that will play, the alarm falls back to the system sound")
    func nothingPlayableFallsBackToSystemSound() {
        let factory = FakeAudioPlayerFactory(failing: [Self.longFile, Self.classicFile])
        let controller = start(factory)

        #expect(factory.attempts == [Self.longFile, Self.classicFile])
        #expect(controller.isUsingSystemSoundFallback)
        #expect(controller.isPlaying)

        controller.stop()  // ends the beep timer, which would otherwise outlive the test
    }

    // MARK: - Stop

    /// The alarm ducks other audio. Without `.notifyOthersOnDeactivation`, an app it
    /// interrupted is never told it may resume.
    @Test("Stopping deactivates the session so other audio can resume")
    func stopNotifiesOthers() {
        let session = FakeAudioSession()
        let factory = FakeAudioPlayerFactory()
        let controller = start(factory, session: session)

        controller.stop()

        #expect(session.calls.last == .setActive(false, [.notifyOthersOnDeactivation]))
        #expect(factory.players.first?.wasStopped == true)
        #expect(!controller.isPlaying)
    }

    @Test("Stopping ends the system-sound fallback")
    func stopEndsSystemSound() {
        let factory = FakeAudioPlayerFactory(failing: [Self.longFile, Self.classicFile])
        let controller = start(factory)

        controller.stop()

        #expect(!controller.isUsingSystemSoundFallback)
        #expect(!controller.isPlaying)
    }
}
