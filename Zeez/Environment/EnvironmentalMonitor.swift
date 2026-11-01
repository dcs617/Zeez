import CoreData
import AVFoundation
import UIKit
import os.log

/// The slice of `AVAudioRecorder` the monitor uses, so tests can stand in a fake meter.
protocol NoiseMeter: AnyObject {
    var isRecording: Bool { get }
    func record() -> Bool
    func stop()
    func updateMeters()
    func averagePower(forChannel channelNumber: Int) -> Float
}

extension AVAudioRecorder: NoiseMeter {}

/// Samples the room's noise while a recording runs, all night (2026-11-01).
///
/// The app keeps running with the phone locked because the recording holds a live microphone
/// (UIBackgroundModes `audio`); without one, iOS suspends it and nothing is sampled. Only noise
/// is genuinely measured (microphone metering); iPhones have no ambient temperature/humidity
/// sensor and no usable ambient-light API, so those attributes are stored as
/// `EnvironmentalReading.notMeasured` rather than fabricated (the previous
/// camera-ISO "light level" never measured anything without a capture session).
///
/// Noise is `notMeasured` whenever the meter is not hearing the room: the alarm holds the
/// session, a call interrupted it, the route changed under it, or it has only just started. A
/// stopped meter reads −160 dB, which would be stored as the quietest possible room.
final class EnvironmentalMonitor {
    static let shared = EnvironmentalMonitor()

    /// How long a meter runs before its level means anything.
    static let meterWarmUp: TimeInterval = 1

    private let persistenceController: PersistenceController
    private let coordinator: AudioSessionCoordinator
    private let microphone: MicrophonePermission
    private let errors: ErrorManager
    private let makeMeter: () throws -> NoiseMeter
    private let now: () -> Date
    private var meter: NoiseMeter?
    private var meterStartedAt: Date?
    private var monitoringTimer: Timer?
    private let samplingInterval: TimeInterval = 300 // 5 minutes
    /// A failed save alerts once per recording, not every five minutes all night.
    private var hasReportedSaveFailure = false

    /// Tests inject an in-memory store, their own coordinator and error manager, fakes for the
    /// microphone and the meter, and a clock.
    init(persistenceController: PersistenceController = .shared,
         coordinator: AudioSessionCoordinator = .shared,
         microphone: MicrophonePermission = LiveMicrophonePermission(),
         errors: ErrorManager = .shared,
         makeMeter: @escaping () throws -> NoiseMeter = EnvironmentalMonitor.makeRecorder,
         now: @escaping () -> Date = Date.init) {
        self.persistenceController = persistenceController
        self.coordinator = coordinator
        self.microphone = microphone
        self.errors = errors
        self.makeMeter = makeMeter
        self.now = now
        removeLegacyRecordingFile()
        // The alarm outranks the recording for the audio session, and the system can take the
        // session away. While the input is gone the meter is stopped, so samples read
        // "not measured", and it restarts when the input comes back.
        coordinator.recordingInputChanged = { [weak self] hasInput in
            DispatchQueue.main.async {
                guard let self, self.monitoringTimer != nil else { return }
                if hasInput {
                    self.ensureMeter()
                } else {
                    self.stopMeter()
                }
            }
        }
    }

    /// Starts sampling. Main thread. Throws when the microphone is not allowed or does not
    /// start: a recording measures nothing without it (decision 2026-11-01), so the caller
    /// does not start one. `SleepRecordingController` asks for access before it gets here.
    func startMonitoring(for session: SleepSession) throws {
        stopMonitoring()

        guard microphone.isGranted else { throw AppError.microphonePermissionDenied }
        try coordinator.acquire(.recording)
        // A sound preview may hold the session for a moment: the meter then starts when it
        // is handed back.
        if coordinator.recordingHasInput {
            do {
                try startMeter()
            } catch {
                coordinator.release(.recording)
                throw error
            }
        }

        hasReportedSaveFailure = false
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: samplingInterval, repeats: true) { [weak self] _ in
            self?.captureSample(for: session)
        }
    }

    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        stopMeter()
        // Deactivates the session only if the alarm does not hold it.
        coordinator.release(.recording)
    }

    /// Whether a recording is being sampled. For tests.
    var isMonitoring: Bool { monitoringTimer != nil }

    func getEnvironmentalReadings(for session: SleepSession) throws -> [EnvironmentalReading] {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<EnvironmentalReading> = EnvironmentalReading.fetchRequest()
        request.predicate = NSPredicate(format: "session == %@", session)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \EnvironmentalReading.timestamp, ascending: true)]

        do {
            return try context.fetch(request)
        } catch {
            errors.reportError(AppError.dataProcessingFailed)
            throw error
        }
    }

    /// Takes one sample. The timer calls it every `samplingInterval`; tests call it directly.
    func captureSample(for session: SleepSession) {
        let noise = currentNoiseLevel()
        // iOS does not promise to say when an interruption ends, and a route change can stop
        // the meter: a sample that finds it stopped asks for the input back.
        if meter?.isRecording != true {
            coordinator.reactivateRecording()
        }

        let context = persistenceController.container.viewContext

        let reading = EnvironmentalReading(context: context)
        reading.id = UUID()
        reading.timestamp = now()
        reading.deviceType = UIDevice.current.model
        reading.session = session

        // Noise is the only metric this hardware can genuinely measure — the
        // rest are marked not-measured instead of fabricated (2.9, see class doc).
        reading.noiseLevel = noise
        reading.lightLevel = EnvironmentalReading.notMeasured
        reading.temperature = EnvironmentalReading.notMeasured
        reading.humidity = EnvironmentalReading.notMeasured

        do {
            try context.save()
        } catch {
            // Left in the context, the reading would make every later save fail with it.
            context.delete(reading)
            ZeezLogger.error(ZeezLogger.environment, "Noise sample not saved", error: error)
            if !hasReportedSaveFailure {
                hasReportedSaveFailure = true
                errors.report(.saveFailed)
            }
        }
    }

    /// Returns a relative noise index (0–100), not decibels (see `NoiseIndex`), or
    /// `notMeasured` when the meter is not hearing the room.
    private func currentNoiseLevel() -> Double {
        guard let meter, meter.isRecording,
              let startedAt = meterStartedAt,
              now().timeIntervalSince(startedAt) >= Self.meterWarmUp else {
            return EnvironmentalReading.notMeasured
        }
        meter.updateMeters()
        return NoiseIndex.fromAveragePower(meter.averagePower(forChannel: 0))
    }

    /// Restarts the meter when it has stopped. The input must be live.
    private func ensureMeter() {
        guard meter?.isRecording != true else { return }
        do {
            try startMeter()
        } catch {
            ZeezLogger.error(ZeezLogger.environment, "Microphone did not restart", error: error)
        }
    }

    private func startMeter() throws {
        stopMeter()
        let meter = try makeMeter()
        guard meter.record() else { throw AppError.sensorDataUnavailable }
        self.meter = meter
        meterStartedAt = now()
    }

    private func stopMeter() {
        meter?.stop()
        meter = nil
        meterStartedAt = nil
    }

    /// Metering only — record to /dev/null so no audio ever reaches disk.
    /// The NSMicrophoneUsageDescription promises on-device analysis with
    /// no storage or upload; this is what keeps that claim true.
    static func makeRecorder() throws -> NoiseMeter {
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatAppleIMA4),
            AVSampleRateKey: 8000.0,
            AVNumberOfChannelsKey: 1
        ]
        let recorder = try AVAudioRecorder(url: URL(fileURLWithPath: "/dev/null"), settings: settings)
        recorder.isMeteringEnabled = true
        return recorder
    }

    /// Earlier builds recorded lossless audio to Documents indefinitely
    /// ("environmental_audio.caf"). Delete anything left behind.
    private func removeLegacyRecordingFile() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let legacyURL = documentsPath.appendingPathComponent("environmental_audio.caf")
        try? FileManager.default.removeItem(at: legacyURL)
    }

    /// Asks for the microphone. Asking needs no audio-session category.
    func checkSensorAvailability(completion: @escaping (Bool) -> Void) {
        microphone.request(completion)
    }

    deinit {
        stopMonitoring()
    }
}
