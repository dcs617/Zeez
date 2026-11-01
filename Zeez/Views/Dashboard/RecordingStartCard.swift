import SwiftUI

/// Starts a recording from the Sleep tab (2026-11-01). The recording itself runs in
/// `RecordingView`, which `RootView` lays over the whole app.
struct RecordingStartCard: View {
    @ObservedObject private var recording = SleepRecordingController.shared
    @State private var isStarting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Record Tonight", systemImage: "moon.zzz.fill")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            Text("Put your phone on your nightstand, plugged in. Zeez measures how loud your room is through the night, and ends the recording just before your alarm.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: start) {
                HStack {
                    if isStarting {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(isStarting ? "Starting…" : "Start Recording")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isStarting)
            .accessibilityLabel(isStarting ? "Starting the recording" : "Start recording")
            .accessibilityHint("Records tonight. Zeez asks for the microphone the first time.")
            .accessibilityIdentifier("startRecordingButton")

            Text("Audio is analyzed on your iPhone and never stored or uploaded.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("recordingStartCard")
    }

    /// A refused microphone or a failed start alerts from the controller.
    private func start() {
        isStarting = true
        recording.start { _ in
            isStarting = false
        }
    }
}

#Preview {
    RecordingStartCard()
        .padding()
}
