import Testing
import CoreData
import HealthKit
@testable import Zeez

/// Tests that SleepStageType.normalize decodes both the uppercase (mock/analyzer) and
/// lowercase (HealthKit/Pillow import) stored representations consistently.
struct SleepStageNormalizationTests {

    // MARK: - Canonical Decoding

    @Test("Uppercase stored values decode to correct stage types")
    func uppercaseStoredValuesDecodeCorrectly() {
        #expect(SleepStageType.normalize("AWAKE") == .awake)
        #expect(SleepStageType.normalize("LIGHT") == .lightSleep)
        #expect(SleepStageType.normalize("DEEP") == .deepSleep)
        #expect(SleepStageType.normalize("REM") == .rem)
        #expect(SleepStageType.normalize("ASLEEP_UNSPECIFIED") == .asleepUnspecified)
    }

    @Test("Lowercase stored values decode to correct stage types")
    func lowercaseStoredValuesDecodeCorrectly() {
        #expect(SleepStageType.normalize("awake") == .awake)
        #expect(SleepStageType.normalize("light") == .lightSleep)
        #expect(SleepStageType.normalize("deep") == .deepSleep)
        #expect(SleepStageType.normalize("rem") == .rem)
        #expect(SleepStageType.normalize("asleepUnspecified") == .asleepUnspecified)
    }

    @Test("Mixed-case stored values decode correctly")
    func mixedCaseDecodes() {
        #expect(SleepStageType.normalize("Awake") == .awake)
        #expect(SleepStageType.normalize("Light") == .lightSleep)
        #expect(SleepStageType.normalize("Deep") == .deepSleep)
        #expect(SleepStageType.normalize("Rem") == .rem)
    }

    @Test("Unknown and import-specific values return nil")
    func unknownValuesReturnNil() {
        #expect(SleepStageType.normalize("inBed") == nil)
        #expect(SleepStageType.normalize("unknown") == nil)
        #expect(SleepStageType.normalize("") == nil)
        #expect(SleepStageType.normalize(nil) == nil)
        #expect(SleepStageType.normalize("INBED") == nil)
    }

    @Test("matches(_:) returns true for both casings")
    func matchesHandlesBothCasings() {
        #expect(SleepStageType.deepSleep.matches("deep"))
        #expect(SleepStageType.deepSleep.matches("DEEP"))
        #expect(SleepStageType.awake.matches("awake"))
        #expect(SleepStageType.awake.matches("AWAKE"))
        #expect(SleepStageType.rem.matches("rem"))
        #expect(SleepStageType.rem.matches("REM"))
        #expect(SleepStageType.lightSleep.matches("light"))
        #expect(SleepStageType.lightSleep.matches("LIGHT"))
        #expect(SleepStageType.asleepUnspecified.matches("asleepUnspecified"))
    }

    @Test("HealthKit unspecified asleep remains unspecified and in-bed remains contextual")
    func healthKitSourceValuesPreserveMeaning() {
        #expect(healthKitSleepStageType(for: HKCategoryValueSleepAnalysis.asleepCore.rawValue) == "light")
        #expect(healthKitSleepStageType(for: HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue) == "asleepUnspecified")
        #expect(healthKitSleepStageType(for: HKCategoryValueSleepAnalysis.inBed.rawValue) == "inBed")
    }

    @Test("Apple Health Core stage uses its source-reported display name")
    func appleHealthCoreDisplayNamePreservesProvenance() {
        #expect(SleepStageType.lightSleep.displayName(reportedByAppleHealth: true) == "Core Sleep")
        #expect(SleepStageType.lightSleep.displayName(reportedByAppleHealth: false) == "Light Sleep")
        #expect(SleepStageType.asleepUnspecified.displayName(reportedByAppleHealth: true) == "Asleep (Unspecified)")
    }

    @Test("Overlapping in-bed interval is excluded from displayed stage distribution")
    func inBedDoesNotDistortStageDistribution() {
        let distribution = displayableStageDurations(from: [
            StoredSleepStageDuration(type: "inBed", duration: 8 * 3600),
            StoredSleepStageDuration(type: "light", duration: 4 * 3600),
            StoredSleepStageDuration(type: "deep", duration: 2 * 3600),
            StoredSleepStageDuration(type: "rem", duration: 2 * 3600)
        ])

        let total = distribution.values.reduce(0, +)
        #expect(total == 8 * 3600)
        #expect(abs(distribution[.lightSleep, default: 0] - 4 * 3600) < 0.01)
        #expect(abs(distribution[.deepSleep, default: 0] - 2 * 3600) < 0.01)
        #expect(abs(distribution[.rem, default: 0] - 2 * 3600) < 0.01)
        #expect(distribution[.asleepUnspecified] == nil)
    }

    @Test("Awake interval is excluded from asleep composition percentages")
    func awakeIsContextNotSleepComposition() {
        let distribution = asleepStageDurations(from: [
            StoredSleepStageDuration(type: "awake", duration: 60 * 60),
            StoredSleepStageDuration(type: "light", duration: 4 * 3600),
            StoredSleepStageDuration(type: "deep", duration: 2 * 3600),
            StoredSleepStageDuration(type: "rem", duration: 2 * 3600)
        ])

        #expect(distribution[.awake] == nil)
        #expect(distribution.values.reduce(0, +) == 8 * 3600)
    }

    @Test("Dashboard stage preview reports stage duration without calling it a cycle")
    func dashboardPreviewReportsStageDistribution() {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let session = SleepSession(context: context)

        for (type, duration) in [("inBed", 8 * 3600.0), ("rem", 2 * 3600.0)] {
            let stage = SleepStage(context: context)
            stage.stageType = type
            stage.duration = duration
            stage.session = session
        }

        let stat = SleepStagesPreviewStats.getRandomStat(from: session)
        #expect(stat?.label == "REM")
        #expect(stat?.value == "100%")
    }

    @Test("In-bed or asleep rows alone do not support an estimated efficiency rating")
    func efficiencyRequiresRecordedAwakeInterval() {
        #expect(!hasRecordedAwakeInterval(in: [
            StoredSleepStageDuration(type: "inBed", duration: 8 * 3600),
            StoredSleepStageDuration(type: "asleepUnspecified", duration: 7 * 3600)
        ]))
        #expect(hasRecordedAwakeInterval(in: [
            StoredSleepStageDuration(type: "awake", duration: 10 * 60),
            StoredSleepStageDuration(type: "light", duration: 7 * 3600)
        ]))
    }

    @Test("matches(_:) returns false for non-matching stages")
    func matchesReturnsFalseForMismatch() {
        #expect(!SleepStageType.deepSleep.matches("light"))
        #expect(!SleepStageType.deepSleep.matches("rem"))
        #expect(!SleepStageType.awake.matches("deep"))
        #expect(!SleepStageType.rem.matches(nil))
    }

    // MARK: - Quality Calculator Equivalence

    @Test("Stage percentages match for uppercase and lowercase stored rows")
    func stagePercentsEquivalentAcrossCasings() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        let session = SleepSession(context: context)
        session.id = UUID()
        session.startTime = Date(timeIntervalSinceNow: -8 * 3600)
        session.endTime = Date()

        // Simulate uppercase (mock/analyzer-generated) stages
        func makeStage(type: String, duration: TimeInterval) {
            let stage = SleepStage(context: context)
            stage.id = UUID()
            stage.stageType = type
            stage.duration = duration
            stage.startTime = Date(timeIntervalSinceNow: -duration)
            stage.endTime = Date()
            stage.session = session
        }

        // Two sessions: one with uppercase stages, one with lowercase
        makeStage(type: "DEEP", duration: 90 * 60)
        makeStage(type: "LIGHT", duration: 180 * 60)
        makeStage(type: "REM", duration: 90 * 60)

        try context.save()

        let calcUpper = SleepQualityCalculator(session: session, context: context)
        let metricsUpper = calcUpper.calculateMetrics()

        // Reset stages to lowercase equivalents
        if let stages = session.sleepStages?.allObjects as? [SleepStage] {
            stages.forEach { context.delete($0) }
        }
        makeStage(type: "deep", duration: 90 * 60)
        makeStage(type: "light", duration: 180 * 60)
        makeStage(type: "rem", duration: 90 * 60)
        try context.save()

        let calcLower = SleepQualityCalculator(session: session, context: context)
        let metricsLower = calcLower.calculateMetrics()

        #expect(abs(metricsUpper.stageDistributionScore - metricsLower.stageDistributionScore) < 0.01,
                "Stage distribution scores must be identical for uppercase vs lowercase stored values")
        #expect(abs(metricsUpper.fragmentationScore - metricsLower.fragmentationScore) < 0.01,
                "Fragmentation scores must be identical for uppercase vs lowercase stored values")
    }
}
