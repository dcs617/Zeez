import CoreData
import Foundation
import os.log

final class SleepAnalyzer {
    static let shared = SleepAnalyzer()

    private init() {}

    // MARK: - Sleep Analysis (concurrency-safe entry point)

    /// Analyze a sleep session identified by its `NSManagedObjectID`.
    ///
    /// Accepts an objectID rather than a `SleepSession` instance to avoid passing managed
    /// objects across Core Data queue boundaries. Creates its own private background context
    /// so all object access stays properly queue-confined.
    func analyzeSleepSession(objectID: NSManagedObjectID) async throws {
        try await analyzeSleepSession(objectID: objectID, container: PersistenceController.shared.container)
    }

    /// Testable overload — callers may supply the persistent container used to resolve the
    /// object ID so that tests can inject an in-memory store without touching shared state.
    func analyzeSleepSession(objectID: NSManagedObjectID,
                             container: NSPersistentContainer) async throws {
        let context = container.newBackgroundContext()

        try await context.perform {
            guard let session = try? context.existingObject(with: objectID) as? SleepSession else {
                throw AnalysisError.noDataAvailable
            }
            try self.analyzeInContext(session: session, context: context)
        }
    }

    // MARK: - Private Analysis Pipeline (runs inside context.perform)

    private func analyzeInContext(session: SleepSession, context: NSManagedObjectContext) throws {
        guard let startTime = session.startTime,
              let endTime = session.endTime,
              endTime > startTime else {
            throw AnalysisError.invalidSessionTimes
        }

        let duration = endTime.timeIntervalSince(startTime)
        guard duration >= 30 * 60 else {
            throw AnalysisError.sessionTooShort(duration: duration)
        }

        ZeezLogger.info(ZeezLogger.sleepTracking, "Analyzing sleep session")
        // Session times are health data — keep them out of release logs.
        ZeezLogger.debug(ZeezLogger.sleepTracking, "Session window \(startTime) – \(endTime) (\(String(format: "%.1f", duration / 3600)) h)")

        // Collect supporting data (accessed safely inside context.perform)
        let movements = (session.movementData?.allObjects as? [MovementData] ?? [])
            .sorted { ($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast) }
        let heartRates = (session.heartRateData?.allObjects as? [HeartRateData] ?? [])
            .sorted { ($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast) }

        // HealthKit-imported sessions carry source-reported stages. Never delete or
        // replace them with Zeez-inferred output. BackgroundTaskManager excludes these
        // sessions via predicate, but guard here as a safety net for other callers.
        let isHealthKitImport = session.deviceIdentifier?.contains("HealthKit") == true
        let hasExistingStages = (session.sleepStages?.count ?? 0) > 0
        if isHealthKitImport && hasExistingStages {
            ZeezLogger.info(ZeezLogger.sleepTracking, "Skipping analysis for HealthKit session with source-reported stages")
            return
        }

        // Gate: require at least minimal evidence to run stage inference.
        // Without data the analyzer would only produce fixed-timing guesses that look
        // physiologically plausible but are not measured.
        guard !movements.isEmpty || !heartRates.isEmpty else {
            ZeezLogger.info(ZeezLogger.sleepTracking, "Skipping stage analysis: no movement or heart rate data available")
            // Set a sentinel (1.0) so BackgroundTaskManager does not retry indefinitely.
            // UI treats qualityScore <= 1.0 as "no displayable score" and shows nothing.
            session.qualityScore = 1.0
            try context.save()
            return
        }

        // Idempotency: remove previously Zeez-inferred stages before re-running so reruns
        // do not append duplicate stage records. Only non-HealthKit sessions with sensor
        // data reach this point, so all existing stages here are Zeez-inferred.
        if let existing = session.sleepStages?.allObjects as? [SleepStage] {
            existing.forEach { context.delete($0) }
        }

        // Remove any existing quality score records to avoid duplicates on rerun.
        if let existing = session.qualityScores?.allObjects as? [SleepQualityScore] {
            existing.forEach { context.delete($0) }
        }

        // Analyze sleep stages
        let stageAnalyzer = SleepStageAnalyzer(context: context)
        let stages: [SleepStage]
        do {
            stages = try stageAnalyzer.analyzeSleepStagesSync(for: session,
                                                              movements: movements,
                                                              heartRates: heartRates)
        } catch {
            ZeezLogger.error(ZeezLogger.sleepTracking, "Stage analysis failed", error: error)
            throw error
        }

        // Calculate quality metrics
        let qualityCalculator = SleepQualityCalculator(session: session, context: context)
        let qualityMetrics = qualityCalculator.calculateMetrics()

        // Persist analysis results
        session.qualityScore = qualityMetrics.overallScore

        let qualityScore = SleepQualityScore(context: context)
        qualityScore.id = UUID()
        qualityScore.timestamp = Date()
        qualityScore.overallScore = qualityMetrics.overallScore
        qualityScore.calculationVersion = "SleepAnalyzer-2.0"
        qualityScore.isPersonalized = false
        qualityScore.confidenceScore = 85.0
        qualityScore.session = session

        try context.save()

        let deepCount = stages.filter { SleepStageType.deepSleep.matches($0.stageType) }.count
        let lightCount = stages.filter { SleepStageType.lightSleep.matches($0.stageType) }.count
        let remCount = stages.filter { SleepStageType.rem.matches($0.stageType) }.count
        let awakeCount = stages.filter { SleepStageType.awake.matches($0.stageType) }.count

        ZeezLogger.info(ZeezLogger.sleepTracking, "Analysis complete")
        // Scores and stage distribution are health data — debug builds only.
        ZeezLogger.debug(
            ZeezLogger.sleepTracking,
            "Score: \(Int(qualityMetrics.overallScore)), stages: \(stages.count) (D:\(deepCount) L:\(lightCount) R:\(remCount) W:\(awakeCount))"
        )
    }
}

// MARK: - Analysis Errors

enum AnalysisError: Error, LocalizedError {
    case invalidSessionTimes
    case sessionTooShort(duration: TimeInterval)
    case noDataAvailable
    case coreDataError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidSessionTimes:
            return "Session has invalid start or end times"
        case .sessionTooShort(let duration):
            return "Session too short for analysis: \(Int(duration / 60)) minutes"
        case .noDataAvailable:
            return "No movement or heart rate data available for analysis"
        case .coreDataError(let error):
            return "Core Data error: \(error.localizedDescription)"
        }
    }
}
