import Foundation
import CoreData
import os.log

struct PillowSleepData: Codable {
    let sessions: [PillowSession]
    
    struct PillowSession: Codable {
        let startTime: String
        let endTime: String
        let sleepQuality: Double?
        let sleepStages: [PillowStage]?
        let heartRateData: [PillowHeartRate]?
        let movementData: [PillowMovement]?
        let notes: String?
        
        struct PillowStage: Codable {
            let startTime: String
            let endTime: String
            let stage: String // "awake", "light", "deep", "rem"
        }
        
        struct PillowHeartRate: Codable {
            let timestamp: String
            let value: Double
        }
        
        struct PillowMovement: Codable {
            let timestamp: String
            let intensity: Double // 0.0 to 1.0
        }
    }
}

class PillowDataImporter {
    static let shared = PillowDataImporter()
    
    private let persistenceController = PersistenceController.shared
    private let dateFormatter: DateFormatter
    private let isoDateFormatter: ISO8601DateFormatter
    
    private init() {
        // Standard date formatter for various Pillow export formats
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.timeZone = TimeZone.current
        
        // ISO8601 formatter as backup
        isoDateFormatter = ISO8601DateFormatter()
        isoDateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }
    
    // MARK: - JSON Import
    
    func importFromJSON(data: Data, completion: @escaping (Result<Int, Error>) -> Void) {
        ZeezLogger.info(ZeezLogger.coreData, "Starting Pillow JSON data import")
        
        do {
            let pillowData = try JSONDecoder().decode(PillowSleepData.self, from: data)
            processJsonData(pillowData, completion: completion)
        } catch {
            ZeezLogger.error(ZeezLogger.error, "Failed to decode Pillow JSON: \(error.localizedDescription)")
            completion(.failure(error))
        }
    }
    
    func importFromJSONFile(url: URL, completion: @escaping (Result<Int, Error>) -> Void) {
        do {
            let data = try Data(contentsOf: url)
            importFromJSON(data: data, completion: completion)
        } catch {
            ZeezLogger.error(ZeezLogger.error, "Failed to read Pillow JSON file: \(error.localizedDescription)")
            completion(.failure(error))
        }
    }
    
    private func processJsonData(_ pillowData: PillowSleepData, completion: @escaping (Result<Int, Error>) -> Void) {
        let context = persistenceController.container.newBackgroundContext()
        var importedCount = 0
        
        context.perform {
            for pillowSession in pillowData.sessions {
                if self.createSessionFromPillow(pillowSession, context: context) != nil {
                    importedCount += 1
                }
            }
            
            do {
                try context.save()
                ZeezLogger.info(ZeezLogger.coreData, "Successfully imported \(importedCount) Pillow sessions")
                DispatchQueue.main.async {
                    completion(.success(importedCount))
                }
            } catch {
                ZeezLogger.error(ZeezLogger.error, "Failed to save Pillow data: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // MARK: - CSV Import
    
    func importFromCSV(data: Data, completion: @escaping (Result<Int, Error>) -> Void) {
        ZeezLogger.info(ZeezLogger.coreData, "Starting Pillow CSV data import")
        
        guard let csvString = String(data: data, encoding: .utf8) else {
            completion(.failure(NSError(domain: "PillowImport", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not read CSV data"])))
            return
        }
        
        processCSVData(csvString, completion: completion)
    }
    
    func importFromCSVFile(url: URL, completion: @escaping (Result<Int, Error>) -> Void) {
        do {
            let csvString = try String(contentsOf: url, encoding: .utf8)
            processCSVData(csvString, completion: completion)
        } catch {
            ZeezLogger.error(ZeezLogger.error, "Failed to read Pillow CSV file: \(error.localizedDescription)")
            completion(.failure(error))
        }
    }
    
    private func processCSVData(_ csvString: String, completion: @escaping (Result<Int, Error>) -> Void) {
        let context = persistenceController.container.newBackgroundContext()
        var importedCount = 0
        
        context.perform {
            let lines = csvString.components(separatedBy: .newlines)
            guard lines.count > 1 else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "PillowImport", code: -2, userInfo: [NSLocalizedDescriptionKey: "CSV file has no data rows"])))
                }
                return
            }
            
            // Parse header to understand CSV format
            let header = lines[0].components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            
            for line in lines.dropFirst() {
                if line.isEmpty { continue }
                
                let values = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                if self.createSessionFromCSVRow(header: header, values: values, context: context) != nil {
                    importedCount += 1
                }
            }
            
            do {
                try context.save()
                ZeezLogger.info(ZeezLogger.coreData, "Successfully imported \(importedCount) Pillow CSV sessions")
                DispatchQueue.main.async {
                    completion(.success(importedCount))
                }
            } catch {
                ZeezLogger.error(ZeezLogger.error, "Failed to save Pillow CSV data: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func createSessionFromCSVRow(header: [String], values: [String], context: NSManagedObjectContext) -> SleepSession? {
        guard header.count == values.count else { return nil }
        
        var sessionData: [String: String] = [:]
        for (index, key) in header.enumerated() {
            sessionData[key.lowercased()] = values[index]
        }
        
        // Try to extract start and end times
        guard let startTimeStr = sessionData["start_time"] ?? sessionData["bedtime"] ?? sessionData["start"],
              let endTimeStr = sessionData["end_time"] ?? sessionData["wake_time"] ?? sessionData["end"],
              let startTime = parseDate(startTimeStr),
              let endTime = parseDate(endTimeStr) else {
            ZeezLogger.debug(ZeezLogger.coreData, "Could not parse dates from CSV row: \(sessionData)")
            return nil
        }
        
        // Skip if session already exists
        if sessionExists(startTime: startTime, context: context) {
            return nil
        }
        
        let session = SleepSession(context: context)
        session.id = UUID()
        session.startTime = startTime
        session.endTime = endTime
        session.isActive = false
        session.createdAt = Date()
        session.modifiedAt = Date()
        session.deviceIdentifier = AppConstants.DataProvenance.pillowCSVImport
        
        // Extract quality score if available
        if let qualityStr = sessionData["quality"] ?? sessionData["sleep_quality"],
           let quality = Double(qualityStr) {
            session.qualityScore = min(max(quality, 0), 100)
        } else {
            // Calculate basic quality based on duration
            let duration = endTime.timeIntervalSince(startTime) / 3600
            session.qualityScore = min(max(duration * 12, 0), 100)
        }
        
        // Add notes if available
        if let notes = sessionData["notes"] ?? sessionData["comments"], !notes.isEmpty {
            let sleepNote = SleepNote(context: context)
            sleepNote.id = UUID()
            sleepNote.title = "Imported from Pillow"
            sleepNote.content = notes
            sleepNote.createdAt = Date()
            sleepNote.session = session
        }
        
        ZeezLogger.debug(ZeezLogger.coreData, "Created Pillow CSV session from \(startTime) to \(endTime)")
        return session
    }
    
    private func createSessionFromPillow(_ pillowSession: PillowSleepData.PillowSession, context: NSManagedObjectContext) -> SleepSession? {
        guard let startTime = parseDate(pillowSession.startTime),
              let endTime = parseDate(pillowSession.endTime) else {
            ZeezLogger.debug(ZeezLogger.coreData, "Could not parse dates from Pillow session")
            return nil
        }
        
        // Skip if session already exists
        if sessionExists(startTime: startTime, context: context) {
            return nil
        }
        
        let session = SleepSession(context: context)
        session.id = UUID()
        session.startTime = startTime
        session.endTime = endTime
        session.isActive = false
        session.createdAt = Date()
        session.modifiedAt = Date()
        session.deviceIdentifier = AppConstants.DataProvenance.pillowJSONImport
        session.qualityScore = pillowSession.sleepQuality ?? 75.0
        
        // Import sleep stages
        if let stages = pillowSession.sleepStages {
            for stage in stages {
                guard let stageStart = parseDate(stage.startTime),
                      let stageEnd = parseDate(stage.endTime) else { continue }
                
                let sleepStage = SleepStage(context: context)
                sleepStage.id = UUID()
                sleepStage.startTime = stageStart
                sleepStage.endTime = stageEnd
                sleepStage.duration = stageEnd.timeIntervalSince(stageStart)
                sleepStage.stageType = mapPillowStage(stage.stage)
                sleepStage.confidence = 80.0
                sleepStage.session = session
            }
        }
        
        // Import heart rate data
        if let heartRateData = pillowSession.heartRateData {
            for heartRate in heartRateData {
                guard let timestamp = parseDate(heartRate.timestamp) else { continue }
                
                let hr = HeartRateData(context: context)
                hr.id = UUID()
                hr.timestamp = timestamp
                hr.value = heartRate.value
                hr.deviceType = "Pillow"
                hr.confidence = 75.0
                hr.session = session
            }
        }
        
        // Import movement data
        if let movementData = pillowSession.movementData {
            for movement in movementData {
                guard let timestamp = parseDate(movement.timestamp) else { continue }
                
                let mv = MovementData(context: context)
                mv.id = UUID()
                mv.timestamp = timestamp
                mv.magnitude = movement.intensity
                mv.activityLevel = Int16(min(max(movement.intensity * 5, 0), 5))
                mv.deviceType = "Pillow"
                mv.session = session
            }
        }
        
        // Add notes
        if let notes = pillowSession.notes, !notes.isEmpty {
            let sleepNote = SleepNote(context: context)
            sleepNote.id = UUID()
            sleepNote.title = "Imported from Pillow"
            sleepNote.content = notes
            sleepNote.createdAt = Date()
            sleepNote.session = session
        }
        
        ZeezLogger.debug(ZeezLogger.coreData, "Created Pillow JSON session from \(startTime) to \(endTime)")
        return session
    }
    
    private func mapPillowStage(_ pillowStage: String) -> String {
        switch pillowStage.lowercased() {
        case "awake", "wake":
            return "awake"
        case "light", "light sleep":
            return "light"
        case "deep", "deep sleep":
            return "deep"
        case "rem", "rem sleep":
            return "rem"
        default:
            return "light" // Default to light sleep for unknown stages
        }
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        // Try different date formats common in Pillow exports
        let formats = [
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "MM/dd/yyyy HH:mm:ss",
            "dd/MM/yyyy HH:mm:ss"
        ]
        
        for format in formats {
            dateFormatter.dateFormat = format
            if let date = dateFormatter.date(from: dateString) {
                return date
            }
        }
        
        // Try ISO8601 as backup
        if let date = isoDateFormatter.date(from: dateString) {
            return date
        }
        
        return nil
    }
    
    private func sessionExists(startTime: Date, context: NSManagedObjectContext) -> Bool {
        let request: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        let calendar = Calendar.current
        let tolerance: TimeInterval = 3600 // 1 hour tolerance
        
        request.predicate = NSPredicate(
            format: "startTime >= %@ AND startTime <= %@",
            calendar.date(byAdding: .second, value: -Int(tolerance), to: startTime)! as NSDate,
            calendar.date(byAdding: .second, value: Int(tolerance), to: startTime)! as NSDate
        )
        request.fetchLimit = 1
        
        do {
            let count = try context.count(for: request)
            return count > 0
        } catch {
            ZeezLogger.error(ZeezLogger.error, "Failed to check existing session: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Export Instructions
    
    static func pillowExportInstructions() -> String {
        return """
        To export your Pillow data:
        
        1. Open the Pillow app on your iPhone
        2. Go to Settings (gear icon)
        3. Tap "Export Sleep Data"
        4. Choose either:
           • JSON format (recommended - includes all data)
           • CSV format (basic sleep times and quality)
        5. Share the file to this app using the share sheet
        
        JSON format includes:
        • Sleep stages (Light, Deep, REM, Awake)
        • Heart rate data (if recorded)
        • Movement/restlessness data
        • Sleep quality scores
        • Personal notes
        
        CSV format includes:
        • Sleep start/end times
        • Sleep quality scores
        • Basic notes
        """
    }
}