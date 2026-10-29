import Testing
import Foundation
import AVFoundation
@testable import Zeez

/// Collects what the coordinator tells the recording about its microphone input.
final class RecordingInputLog: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Bool] = []

    var changes: [Bool] {
        lock.lock(); defer { lock.unlock() }
        return storage
    }

    func record(_ hasInput: Bool) {
        lock.lock(); storage.append(hasInput); lock.unlock()
    }
}

/// One owner of the audio session, and the alarm outranks the recording (2026-10-29).
///
/// Before, the alarm, the recording's microphone and the sound preview each set the shared
/// session themselves. With a recording running, that let the alarm's stop deactivate the
/// session under it (iOS then suspends the app in the background), a recording's stop
/// deactivate it under a ringing alarm, and a recorder that restarted mid-ring switch the
/// alarm to play-and-record, which plays through the earpiece.
@Suite("Audio session coordinator")
struct AudioSessionCoordinatorTests {

    private static let alarmCategory = FakeAudioSession.Call.setCategory(.playback, alarmOptions)
    private static let recordingCategory = FakeAudioSession.Call.setCategory(.playAndRecord, [.mixWithOthers])

    #if compiler(>=6.2)
    private static let alarmOptions: AVAudioSession.CategoryOptions = [.duckOthers, .allowBluetoothHFP]
    #else
    private static let alarmOptions: AVAudioSession.CategoryOptions = [.duckOthers, .allowBluetooth]
    #endif

    private func coordinator() -> (AudioSessionCoordinator, FakeAudioSession, RecordingInputLog) {
        let session = FakeAudioSession()
        let coordinator = AudioSessionCoordinator(session: session)
        let log = RecordingInputLog()
        coordinator.recordingInputChanged = { log.record($0) }
        return (coordinator, session, log)
    }

    @Test("The alarm takes the session from a recording with exactly its own configuration")
    func alarmOutranksRecording() throws {
        let (coordinator, session, log) = coordinator()
        try coordinator.acquire(.recording)
        let before = session.calls.count

        try coordinator.acquire(.alarm)

        #expect(Array(session.calls.dropFirst(before)) == [Self.alarmCategory, .setActive(true, [])])
        #expect(log.changes == [false], "The recording must hear that its input is gone")
        #expect(!coordinator.recordingHasInput)
    }

    @Test("When the alarm stops during a recording, the session stays active and the recording gets its microphone back")
    func alarmStopHandsBackToRecording() throws {
        let (coordinator, session, log) = coordinator()
        try coordinator.acquire(.recording)
        try coordinator.acquire(.alarm)
        let before = session.calls.count

        coordinator.release(.alarm)

        let after = Array(session.calls.dropFirst(before))
        #expect(!after.contains(.setActive(false, [.notifyOthersOnDeactivation])),
                "Deactivating here lets iOS suspend the app under the recording")
        #expect(after == [Self.recordingCategory, .setActive(true, [])])
        #expect(log.changes == [false, true])
        #expect(coordinator.recordingHasInput)
    }

    @Test("A recording that stops while the alarm rings leaves the alarm's session alone")
    func recordingStopDuringAlarmTouchesNothing() throws {
        let (coordinator, session, _) = coordinator()
        try coordinator.acquire(.recording)
        try coordinator.acquire(.alarm)
        let before = session.calls.count

        coordinator.release(.recording)

        #expect(session.calls.count == before, "Any call here would change or end the ringing alarm's session")
        #expect(coordinator.currentHolders == [.alarm])
    }

    @Test("A recording that starts while the alarm rings waits, so the alarm never moves to the earpiece")
    func recordingStartDuringAlarmWaits() throws {
        let (coordinator, session, log) = coordinator()
        try coordinator.acquire(.alarm)
        let before = session.calls.count

        try coordinator.acquire(.recording)

        #expect(session.calls.count == before)
        #expect(!coordinator.recordingHasInput)
        #expect(log.changes.isEmpty)

        coordinator.release(.alarm)
        #expect(coordinator.recordingHasInput)
        #expect(log.changes == [true])
    }

    @Test("A preview never outranks the alarm, and hands the session back to a recording")
    func previewSitsBetween() throws {
        let (coordinator, session, log) = coordinator()
        try coordinator.acquire(.recording)
        try coordinator.acquire(.alarm)
        let before = session.calls.count

        try coordinator.acquire(.preview)
        #expect(session.calls.count == before, "A preview must not reconfigure a ringing alarm")

        coordinator.release(.alarm)
        coordinator.release(.preview)
        #expect(coordinator.recordingHasInput)
        #expect(log.changes == [false, true])
    }

    @Test("With nobody else holding it, letting go deactivates and lets other audio resume")
    func lastReleaseDeactivates() throws {
        let (coordinator, session, _) = coordinator()
        try coordinator.acquire(.recording)

        coordinator.release(.recording)

        #expect(session.calls.last == .setActive(false, [.notifyOthersOnDeactivation]))
        #expect(coordinator.currentHolders.isEmpty)
    }

    @Test("Releasing what is not held does nothing")
    func releasingNothingIsANoOp() {
        let (coordinator, session, _) = coordinator()
        coordinator.release(.alarm)
        #expect(session.calls.isEmpty)
    }

    @Test("The alarm controller's stop during a recording keeps the session active")
    func alarmControllerStopDuringRecording() throws {
        let session = FakeAudioSession()
        let coordinator = AudioSessionCoordinator(session: session)
        let alarm = AlarmAudioController(coordinator: coordinator, players: FakeAudioPlayerFactory())
        try coordinator.acquire(.recording)

        alarm.startLooping(bundledName: "Zeez_Long_Default")
        #expect(session.calls.contains(Self.alarmCategory))
        let before = session.calls.count

        alarm.stop()

        #expect(!Array(session.calls.dropFirst(before)).contains(.setActive(false, [.notifyOthersOnDeactivation])))
        #expect(coordinator.recordingHasInput)
    }
}

/// Only `AudioSessionCoordinator` configures the audio session.
///
/// A second caller of `setCategory` or `setActive` is how a recording could quiet or cut off
/// the alarm (see `AudioSessionCoordinatorTests`). Add a client to the coordinator instead.
struct AudioSessionGuardTests {

    private static let owner = "Zeez/Infrastructure/AudioSessionCoordinator.swift"

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func appSources() throws -> [(path: String, contents: String)] {
        var sources: [(String, String)] = []
        for folder in ["Zeez", "Shared"] {
            let root = Self.repoRoot.appendingPathComponent(folder)
            guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
                continue
            }
            for case let url as URL in walker where url.pathExtension == "swift" {
                let relative = url.path.replacingOccurrences(of: Self.repoRoot.path + "/", with: "")
                sources.append((relative, try String(contentsOf: url, encoding: .utf8)))
            }
        }
        return sources
    }

    /// Code lines that configure the session, ignoring comments.
    static func sessionCalls(in source: String) -> [String] {
        source.components(separatedBy: .newlines).filter { line in
            let code = line.trimmingCharacters(in: .whitespaces)
            guard !code.hasPrefix("//"), !code.hasPrefix("///") else { return false }
            return code.contains(".setCategory(") || code.contains(".setActive(")
                || code.contains("AVAudioSession.sharedInstance()")
        }
    }

    @Test("The scan finds the coordinator's own calls, so this guard is actually scanning something")
    func ownerIsFound() throws {
        let sources = try appSources()
        #expect(sources.count > 20)
        let owner = try #require(sources.first { $0.path == Self.owner }, "\(Self.owner) moved; update this guard")
        #expect(Self.sessionCalls(in: owner.contents).count >= 4)
    }

    @Test("No other file configures the audio session")
    func onlyTheCoordinatorConfiguresTheSession() throws {
        for (path, contents) in try appSources() where path != Self.owner {
            let found = Self.sessionCalls(in: contents)
            #expect(found.isEmpty,
                    "\(path) configures the audio session directly: \(found). Go through AudioSessionCoordinator, so the alarm always outranks a recording.")
        }
    }
}
