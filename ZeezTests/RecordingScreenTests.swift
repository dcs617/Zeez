import Testing
import CoreData
import Foundation
@testable import Zeez

/// The recording screen (2026-11-01): a summary within the claims contract, notes kept with
/// their night and out of Learn, and a screen that never blocks the alarm.
///
/// Before, the parked screen's Add Note did nothing, its summary was a flag no view read, and
/// nothing routed to it at all.
@Suite("The recording screen", .serialized) @MainActor
struct RecordingScreenTests {

    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()

    private func source(_ relative: String) throws -> String {
        try String(contentsOf: Self.repoRoot.appendingPathComponent(relative), encoding: .utf8)
    }

    private func night(noise: [Double], in context: NSManagedObjectContext) throws -> SleepSession {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let session = SleepSession(context: context)
        session.id = UUID()
        session.startTime = start
        session.endTime = start.addingTimeInterval(7 * 3600)
        for (index, level) in noise.enumerated() {
            let reading = EnvironmentalReading(context: context)
            reading.id = UUID()
            reading.timestamp = start.addingTimeInterval(Double(index) * 300)
            reading.noiseLevel = level
            reading.session = session
        }
        try context.save()
        return session
    }

    private func recordingController() -> (SleepRecordingController, PersistenceController) {
        let persistence = PersistenceController(inMemory: true)
        let controller = SleepRecordingController(
            manager: SleepSessionManager(persistenceController: persistence, monitors: FakeSessionMonitors()),
            notificationCenter: FakeNotificationCenter(),
            microphone: FakeMicrophonePermission(granted: true),
            errors: ErrorManager())
        return (controller, persistence)
    }

    private func start(_ controller: SleepRecordingController) async throws -> SleepSession {
        try await withCheckedThrowingContinuation { continuation in
            controller.start { continuation.resume(with: $0) }
        }
    }

    private func end(_ controller: SleepRecordingController, at date: Date) async throws -> SessionEndOutcome {
        try await withCheckedThrowingContinuation { continuation in
            controller.end(at: date) { continuation.resume(with: $0) }
        }
    }

    // MARK: Summary

    @Test("Unmeasured samples are left out of the night's noise, never counted as quiet")
    func unmeasuredSamplesAreLeftOut() throws {
        let context = PersistenceController(inMemory: true).container.viewContext
        let notMeasured = EnvironmentalReading.notMeasured
        let session = try night(noise: [notMeasured, 85, notMeasured, 84, notMeasured, 86], in: context)

        let summary = try #require(RecordingSummary(session: session))

        #expect(summary.sampleCount == 6)
        #expect(summary.measuredSampleCount == 3)
        #expect(summary.typicalNoise == 85, "Counting the gaps as silence would drag a noisy night down to quiet")
        #expect(summary.noiseLevel == .noisy)
        #expect(summary.hasNoiseGaps)
        #expect(summary.noiseCoverage == 0.5)
    }

    @Test("A night the meter never heard says noise was not measured")
    func noMeasuredSampleIsNotMeasured() throws {
        let context = PersistenceController(inMemory: true).container.viewContext
        let session = try night(noise: [EnvironmentalReading.notMeasured, EnvironmentalReading.notMeasured], in: context)

        let summary = try #require(RecordingSummary(session: session))

        #expect(summary.typicalNoise == nil)
        #expect(summary.noiseLevel == nil, "Not 'quiet': nothing was heard")
    }

    @Test("The summary gives the recorded window, not time asleep")
    func summaryIsTheRecordedWindow() throws {
        let context = PersistenceController(inMemory: true).container.viewContext
        let session = try night(noise: [60, 62, 64], in: context)

        let summary = try #require(RecordingSummary(session: session))

        #expect(summary.duration == 7 * 3600)
        #expect(summary.typicalNoise == 62)
        #expect(summary.noiseLevel == .quiet)
        #expect(!summary.hasNoiseGaps)
    }

    // MARK: Ending

    @Test("Ending a recording shows its summary until it is closed")
    func endingShowsTheSummary() async throws {
        let (controller, _) = recordingController()
        let session = try await start(controller)
        #expect(controller.isShowingRecording)

        let endTime = try #require(session.startTime).addingTimeInterval(20 * 60)
        _ = try await end(controller, at: endTime)

        guard case .saved(let summary) = controller.finished else {
            Issue.record("No summary after the recording ended: \(String(describing: controller.finished))")
            return
        }
        #expect(summary.end == endTime)
        #expect(controller.isShowingRecording, "The summary keeps the recording screen up")

        controller.dismissSummary()
        #expect(controller.finished == nil)
        #expect(!controller.isShowingRecording)
    }

    @Test("A recording too short to keep says so")
    func shortRecordingSaysSo() async throws {
        let (controller, _) = recordingController()
        let session = try await start(controller)

        _ = try await end(controller, at: try #require(session.startTime).addingTimeInterval(60))

        #expect(controller.finished == .discardedTooShort)
    }

    // MARK: Notes

    @Test("A note joins its night and stays out of Learn's notes")
    func noteJoinsItsNight() async throws {
        let (controller, persistence) = recordingController()
        let session = try await start(controller)
        let context = persistence.container.viewContext
        let learnNote = SleepNote(context: context)
        learnNote.id = UUID()
        learnNote.content = "From an article"
        try context.save()

        #expect(!controller.addNote("   "), "A blank note is not a note")
        #expect(controller.addNote("Coffee at 4 pm"))

        let notes = session.notes?.allObjects as? [SleepNote] ?? []
        #expect(notes.map(\.content) == ["Coffee at 4 pm"])
        #expect(notes.first?.category == SleepNote.recordingCategory)

        let request: NSFetchRequest<SleepNote> = SleepNote.fetchRequest()
        request.predicate = SleepNote.learnNotesPredicate
        #expect(try context.fetch(request).map(\.content) == ["From an article"])
    }

    @Test("Every Learn list of notes shows Learn's notes only")
    func learnFetchesAreScoped() throws {
        let fetching = ["Zeez/Learn/LearnSearchResults.swift", "Zeez/Learn/Note/LearnNoteLinker.swift",
                        "Zeez/Learn/LearnStatisticsView.swift", "Zeez/Views/NotesSelectionView.swift"]
        for path in fetching {
            #expect(try source(path).contains("SleepNote.learnNotesPredicate"),
                    "\(path) lists notes from recorded nights as Learn notes")
        }

        // Any other view that starts fetching notes has to choose a scope too.
        for directory in ["Zeez/Learn", "Zeez/Views"] {
            let files = FileManager.default.enumerator(at: Self.repoRoot.appendingPathComponent(directory),
                                                       includingPropertiesForKeys: nil)?
                .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" } ?? []
            for file in files {
                let contents = try String(contentsOf: file, encoding: .utf8)
                if contents.contains("FetchRequest<SleepNote>") || contents.contains("FetchedResults<SleepNote>") {
                    #expect(contents.contains("SleepNote.learnNotesPredicate"),
                            "\(file.lastPathComponent) fetches notes without SleepNote.learnNotesPredicate")
                }
            }
        }
    }

    // MARK: Never in the alarm's way

    @Test("The recording lies over the app; the alarm stays RootView's only full-screen cover")
    func recordingNeverBlocksTheAlarm() throws {
        let root = try source("Zeez/Views/RootView.swift")
        #expect(root.contains("RecordingView()"), "Nothing shows the recording")
        #expect(root.components(separatedBy: ".fullScreenCover(").count - 1 == 1,
                "A second cover would stop the alarm screen from presenting while it is up")
        #expect(root.components(separatedBy: ".sheet(").count - 1 == 1)
    }

    @Test("The Sleep tab offers a recording")
    func dashboardOffersARecording() throws {
        #expect(try source("Zeez/Views/DashboardView.swift").contains("RecordingStartCard()"))
    }
}
