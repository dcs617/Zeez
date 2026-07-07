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
    /// Set when the user has denied mic access so sampling degrades to
    /// non-noise metrics without re-reporting an error every interval.
    private var microphoneDenied = false

    private init() {
        self.persistenceController = .shared
        removeLegacyRecordingFile()
    }

    func startMonitoring(for session: SleepSession) {
        stopMonitoring()

        // Noise sampling needs the microphone — ask before first use and
        // degrade to light/temperature-only monitoring if the user declines.
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                self.microphoneDenied = !granted
                if granted {
                    self.startRecorder()
                } else {
                    ZeezLogger.info(ZeezLogger.environment, "Microphone permission denied — monitoring without noise sampling")
                }
                self.monitoringTimer = Timer.scheduledTimer(withTimeInterval: self.samplingInterval, repeats: true) { [weak self] _ in
                    self?.captureEnvironmentalData(for: session)
                }
                self.monitoringTimer?.fire()
                self.errorManager.showStatus("Environmental monitoring started — samples while Zeez is open")
            }
        }
    }

    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        audioRecorder?.stop()
        audioRecorder = nil
        try? AVAudioSession.sharedInstance().setActive(false)
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
    
    private func startRecorder() {
        let audioSession = AVAudioSession.sharedInstance()

        do {
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [])
            try audioSession.setActive(true)

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
            recorder.record()
            audioRecorder = recorder

        } catch {
            errorManager.reportError(AppError.sensorDataUnavailable)
        }
    }

    /// Earlier builds recorded lossless audio to Documents indefinitely
    /// ("environmental_audio.caf"). Delete anything left behind.
    private func removeLegacyRecordingFile() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let legacyURL = documentsPath.appendingPathComponent("environmental_audio.caf")
        try? FileManager.default.removeItem(at: legacyURL)
    }
    
    func checkSensorAvailability(completion: @escaping (Bool) -> Void) {
        let audioSession = AVAudioSession.sharedInstance()

        do {
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [])

            // The microphone is the only sensor monitoring actually uses (2.9).
            AVAudioApplication.requestRecordPermission { hasPermission in
                completion(hasPermission)
            }
        } catch {
            completion(false)
        }
    }

    private func captureNoiseLevel() -> Double {
        // Mic denied or recorder unavailable — record "not measured", not silence.
        guard !microphoneDenied else { return EnvironmentalReading.notMeasured }
        guard let recorder = audioRecorder else {
            errorManager.reportError(AppError.sensorDataUnavailable)
            return EnvironmentalReading.notMeasured
        }

        recorder.updateMeters()
        let averagePower = recorder.averagePower(forChannel: 0)

        // Normalize the decibel reading (typical range is -160 to 0)
        let normalizedValue = Double((averagePower + 160) / 160)

        // Convert to percentage and ensure it's between 0 and 100
        return min(max(normalizedValue * 100, 0), 100)
    }
    
    deinit {
        stopMonitoring()
        audioRecorder?.stop()
    }
}
