import CoreData
import AVFoundation
import UIKit

final class EnvironmentalMonitor {
    static let shared = EnvironmentalMonitor()
    
    private let persistenceController: PersistenceController
    private var audioRecorder: AVAudioRecorder?
    private var monitoringTimer: Timer?
    private let samplingInterval: TimeInterval = 300 // 5 minutes
    private let errorManager = ErrorManager.shared
    
    private init() {
        self.persistenceController = .shared
        setupAudioSession()
    }
    
    func startMonitoring(for session: SleepSession) {
        stopMonitoring()
        
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            monitoringTimer = Timer.scheduledTimer(withTimeInterval: samplingInterval, repeats: true) { [weak self] _ in
                self?.captureEnvironmentalData(for: session)
            }
            monitoringTimer?.fire()
            errorManager.showStatus("Environmental monitoring started")
        } catch {
            errorManager.reportError(AppError.sensorDataUnavailable)
        }
    }
    
    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
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
        
        do {
            reading.lightLevel = captureLightLevel()
            reading.noiseLevel = captureNoiseLevel()
            reading.temperature = estimateRoomTemperature()
            
            try context.save()
        } catch {
            errorManager.reportError(AppError.dataProcessingFailed)
        }
    }
    
    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [])
            try audioSession.setActive(true)
            
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatAppleLossless),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioFilename = documentsPath.appendingPathComponent("environmental_audio.caf")
            
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.prepareToRecord()
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()
            
        } catch {
            errorManager.reportError(AppError.sensorDataUnavailable)
        }
    }
    
    private func captureLightLevel() -> Double {
        guard let device = AVCaptureDevice.default(for: .video) else {
            errorManager.reportError(AppError.sensorDataUnavailable)
            return 0
        }
        
        do {
            try device.lockForConfiguration()
            let currentISO = device.iso
            let minISO = device.activeFormat.minISO
            let maxISO = device.activeFormat.maxISO
            device.unlockForConfiguration()
            
            // Calculate normalized brightness value
            let normalizedBrightness = Double((currentISO - minISO) / (maxISO - minISO))

            // Ensure value is between 0 and 1, then convert to percentage
            let boundedBrightness = min(max(normalizedBrightness, 0), 1)
            return boundedBrightness * 100
        } catch {
            errorManager.reportError(AppError.sensorDataUnavailable)
            return 0
        }
    }
    
    func checkSensorAvailability(completion: @escaping (Bool) -> Void) {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [])
            
            // Check audio session availability
            AVAudioApplication.requestRecordPermission { hasPermission in
                if !hasPermission {
                    completion(false)
                    return
                }
                
                // Check if camera (for light sensor) is available
                guard AVCaptureDevice.default(for: .video) != nil else {
                    completion(false)
                    return
                }

                completion(true)
            }
        } catch {
            completion(false)
        }
    }
    
    private func captureNoiseLevel() -> Double {
        guard let recorder = audioRecorder else {
            errorManager.reportError(AppError.sensorDataUnavailable)
            return 0
        }
        
        recorder.updateMeters()
        let averagePower = recorder.averagePower(forChannel: 0)
        
        // Normalize the decibel reading (typical range is -160 to 0)
        let normalizedValue = Double((averagePower + 160) / 160)

        // Convert to percentage and ensure it's between 0 and 100
        return min(max(normalizedValue * 100, 0), 100)
    }
    
    private func estimateRoomTemperature() -> Double {
        // Placeholder for future temperature sensor integration
        return 0
    }
    
    deinit {
        stopMonitoring()
        audioRecorder?.stop()
    }
}
