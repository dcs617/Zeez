import CoreData
import AVFoundation
import UIKit
import os.log

/// Samples the sleep environment while the app is in the FOREGROUND (2.9).
///
/// Honest scope, per the 1.7 relabel precedent: the sampling timer is suspended
/// with the app, so a locked phone collects nothing overnight — full-night
/// coverage requires Zeez open on a charging device. Only noise is genuinely
/// measured (microphone metering); iPhones have no ambient temperature/humidity
/// sensor and no usable ambient-light API, so those attributes are stored as
/// `EnvironmentalReading.notMeasured` rather than fabricated (the previous
/// camera-ISO "light level" never measured anything without a capture session).
final class EnvironmentalMonitor {
    static let shared = EnvironmentalMonitor()
    
    private let persistenceController: PersistenceController
    private var audioRecorder: AVAudioRecorder?
    private var monitoringTimer: Timer?
    private let samplingInterval: TimeInterval = 300 // 5 minutes
    private let errorManager = ErrorManager.shared
    private let microphone: MicrophonePermission

    private init() {
        self.persistenceController = .shared
        self.microphone = LiveMicrophonePermission()
        removeLegacyRecordingFile()
        // The alarm outranks the recording for the audio session. While it rings the recorder
        // is stopped, so samples read "not measured", and it restarts when the alarm stops.
        AudioSessionCoordinator.shared.recordingInputChanged = { [weak self] hasInput in
            DispatchQueue.main.async {
                guard let self, self.monitoringTimer != nil else { return }
                if hasInput {
                    do {
                        try self.startRecorder()
                    } catch {
                        ZeezLogger.error(ZeezLogger.environment, "Microphone did not restart", error: error)
                    }
                } else {
                    self.audioRecorder?.stop()
                    self.audioRecorder = nil
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
        let coordinator = AudioSessionCoordinator.shared
        try coordinator.acquire(.recording)
        // A sound preview may hold the session for a moment: the recorder then starts when it
        // is handed back.
        if coordinator.recordingHasInput {
            do {
                try startRecorder()
            } catch {
                coordinator.release(.recording)
                throw error
            }
        }

        monitoringTimer = Timer.scheduledTimer(withTimeInterval: samplingInterval, repeats: true) { [weak self] _ in
            self?.captureEnvironmentalData(for: session)
        }
        monitoringTimer?.fire()
    }

    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        audioRecorder?.stop()
        audioRecorder = nil
        // Deactivates the session only if the alarm does not hold it.
        AudioSessionCoordinator.shared.release(.recording)
    }
    
    func getEnvironmentalReadings(for session: SleepSession) throws -> [EnvironmentalReading] {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<EnvironmentalReading> = EnvironmentalReading.fetchRequest()
        request.predicate = NSPredicate(format: "session == %@", session)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \EnvironmentalReading.timestamp, ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            errorManager.reportError(AppError.dataProcessingFailed)
            throw error
        }
    }
    
    private func captureEnvironmentalData(for session: SleepSession) {
        let context = persistenceController.container.viewContext
        
        let reading = EnvironmentalReading(context: context)
        reading.id = UUID()
        reading.timestamp = Date()
        reading.deviceType = UIDevice.current.model
        reading.session = session
        
        // Noise is the only metric this hardware can genuinely measure — the
        // rest are marked not-measured instead of fabricated (2.9, see class doc).
        reading.noiseLevel = captureNoiseLevel()
        reading.lightLevel = EnvironmentalReading.notMeasured
        reading.temperature = EnvironmentalReading.notMeasured
        reading.humidity = EnvironmentalReading.notMeasured

        do {
            try context.save()
        } catch {
            errorManager.reportError(AppError.dataProcessingFailed)
        }
    }
    
    /// Starts the meter. The recording must hold the audio session with its input live.
    private func startRecorder() throws {
        audioRecorder?.stop()
        audioRecorder = nil

        // Metering only — record to /dev/null so no audio ever reaches disk.
        // The NSMicrophoneUsageDescription promises on-device analysis with
        // no storage or upload; this is what keeps that claim true.
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatAppleIMA4),
            AVSampleRateKey: 8000.0,
            AVNumberOfChannelsKey: 1
        ]

        let recorder = try AVAudioRecorder(url: URL(fileURLWithPath: "/dev/null"), settings: settings)
        recorder.isMeteringEnabled = true
        guard recorder.record() else { throw AppError.sensorDataUnavailable }
        audioRecorder = recorder
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
        AVAudioApplication.requestRecordPermission { hasPermission in
            completion(hasPermission)
        }
    }

    /// Returns a relative noise index (0–100), not decibels. See `NoiseIndex`.
    private func captureNoiseLevel() -> Double {
        // Recorder unavailable — record "not measured", not silence.
        guard let recorder = audioRecorder else {
            errorManager.reportError(AppError.sensorDataUnavailable)
            return EnvironmentalReading.notMeasured
        }

        recorder.updateMeters()
        return NoiseIndex.fromAveragePower(recorder.averagePower(forChannel: 0))
    }
    
    deinit {
        stopMonitoring()
        audioRecorder?.stop()
    }
}
