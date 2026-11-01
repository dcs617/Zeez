import SwiftUI
import os.log

/// The recording screen (2026-11-01): the running recording, then its summary.
///
/// `RootView` lays it over the whole app rather than presenting it, so the alarm screen, the
/// app's one full-screen cover, can always present above it. Everything happens in place:
/// a note is typed here and the summary replaces the controls, with no sheet to stack.
struct RecordingView: View {
    @ObservedObject private var recording = SleepRecordingController.shared

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let session = recording.activeSession, let start = session.startTime {
                ActiveRecordingView(start: start, alarmEndTime: recording.alarmEndTime)
            } else if let finished = recording.finished {
                RecordingSummaryView(finished: finished, onDone: recording.dismissSummary)
            }
        }
        .environment(\.colorScheme, .dark)
        .accessibilityIdentifier("recordingView")
    }
}

private struct ActiveRecordingView: View {
    let start: Date
    let alarmEndTime: Date?

    @ObservedObject private var recording = SleepRecordingController.shared
    @StateObject private var batteryAdvice = RecordingBatteryAdviceMonitor()
    @State private var noteText = ""
    @State private var notesSaved = 0
    @State private var isEnding = false
    @FocusState private var isNoteFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Label("Recording", systemImage: "waveform")
                        .font(.headline)
                        .foregroundStyle(.red)
                    ElapsedTimeView(startTime: start)
                        .font(.system(size: 56, weight: .light, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.top, 48)
                .accessibilityElement(children: .combine)

                VStack(spacing: 8) {
                    Text(alarmLine)
                        .accessibilityIdentifier("recordingAlarmLine")
                    Text("You can lock your phone. Leave it on your nightstand.")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

                // A suggestion, never a gate: the recording runs whatever the battery says.
                if let advice = batteryAdvice.message {
                    Label(advice, systemImage: "battery.25")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("batteryAdvice")
                }

                noteSection

                Button(action: end) {
                    Text(isEnding ? "Ending…" : "End Recording")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(isEnding)
                .accessibilityLabel("End recording")
                .accessibilityHint("Stops recording and shows a summary of the night")
                .accessibilityIdentifier("endRecordingButton")
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    private var alarmLine: String {
        guard let alarmEndTime else {
            return "No alarm is set. The recording runs until you end it."
        }
        let time = alarmEndTime.addingTimeInterval(RecordingAlarmBoundary.lead)
            .formatted(date: .omitted, time: .shortened)
        return "Ends just before your \(time) alarm."
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Add a note: caffeine, a late meal, a noisy street", text: $noteText, axis: .vertical)
                .lineLimit(1...4)
                .focused($isNoteFocused)
                .padding(12)
                .background(Color.white.opacity(0.08))
                .cornerRadius(10)
                .accessibilityLabel("Note for tonight")
                .accessibilityHint("Type a note to keep with this night")
                .accessibilityIdentifier("recordingNoteField")

            HStack {
                if notesSaved > 0 {
                    Text(notesSaved == 1 ? "1 note saved" : "\(notesSaved) notes saved")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: saveNote) {
                    Text("Save Note")
                        .fontWeight(.semibold)
                }
                .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Save note")
                .accessibilityHint("Keeps the note with this night")
                .accessibilityIdentifier("saveRecordingNoteButton")
            }
        }
    }

    private func saveNote() {
        if recording.addNote(noteText) {
            noteText = ""
            notesSaved += 1
            isNoteFocused = false
        }
    }

    /// A failed end alerts from the controller and the recording keeps running.
    private func end() {
        isEnding = true
        recording.end { result in
            isEnding = false
            if case .failure(let error) = result {
                ZeezLogger.error(ZeezLogger.sleepTracking, "Recording did not end", error: error)
                ErrorManager.shared.report(.sleepSessionUpdateFailed)
            }
        }
    }
}

/// Only what a phone on the nightstand measured: when the recording ran and how loud the room
/// was (`RecordingSummary`).
private struct RecordingSummaryView: View {
    let finished: FinishedRecording
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                switch finished {
                case .saved(let summary):
                    saved(summary)
                case .discardedTooShort:
                    Text("Recording Not Kept")
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text("Recordings shorter than 15 minutes aren't kept.")
                        .foregroundStyle(.secondary)
                }

                Button(action: onDone) {
                    Text("Done")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .accessibilityLabel("Done")
                .accessibilityHint("Closes the summary")
                .accessibilityIdentifier("recordingSummaryDoneButton")
            }
            .padding(24)
            .padding(.top, 24)
        }
        .accessibilityIdentifier("recordingSummary")
    }

    @ViewBuilder
    private func saved(_ summary: RecordingSummary) -> some View {
        Text("Night Recorded")
            .font(.title2.bold())
            .accessibilityAddTraits(.isHeader)

        Text("\(summary.start.formatted(date: .omitted, time: .shortened)) – \(summary.end.formatted(date: .omitted, time: .shortened))")
            .foregroundStyle(.secondary)

        row("Recorded session duration", FormatterUtils.formattedDuration(start: summary.start, end: summary.end))
            .accessibilityIdentifier("summaryDuration")
        row("Room noise", noiseText(summary))
            .accessibilityIdentifier("summaryNoise")

        if summary.measuredSampleCount > 0, summary.hasNoiseGaps {
            Text("Part of the night wasn't measured: a call, the alarm, or the microphone pausing. Those parts are left out, not counted as quiet.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }

        if summary.noteCount > 0 {
            row("Notes", summary.noteCount == 1 ? "1 note" : "\(summary.noteCount) notes")
        }

        Text("Noise is a relative index from your iPhone's microphone, not decibels. Recorded nights don't get sleep stages or a Zeez score.")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    private func noiseText(_ summary: RecordingSummary) -> String {
        guard let typical = summary.typicalNoise, let level = summary.noiseLevel else { return "Not measured" }
        return "Typically \(level.description) (\(Int(typical.rounded())) \(NoiseIndex.displayUnit))"
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .accessibilityElement(children: .combine)
    }
}

struct ElapsedTimeView: View {
    let startTime: Date
    @State private var elapsedTime: TimeInterval = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Text(formattedElapsedTime)
            .monospacedDigit()
            .onAppear { elapsedTime = Date().timeIntervalSince(startTime) }
            .onReceive(timer) { _ in
                elapsedTime = Date().timeIntervalSince(startTime)
            }
            .accessibilityLabel("Recording for \(accessibleElapsedTime)")
            .accessibilityValue(formattedElapsedTime)
            .accessibilityIdentifier("elapsedTimer")
    }

    private var formattedElapsedTime: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = Int(elapsedTime) / 60 % 60
        return String(format: "%dh %02dm", hours, minutes)
    }

    private var accessibleElapsedTime: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = Int(elapsedTime) / 60 % 60
        let hourText = hours == 1 ? "hour" : "hours"
        let minuteText = minutes == 1 ? "minute" : "minutes"
        return "\(hours) \(hourText) and \(minutes) \(minuteText)"
    }
}
