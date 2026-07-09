import Testing
@testable import Zeez

/// Guards the stage-composition contract `SleepInformationView` presents (B6):
/// every asleep stage is shown, awake is never inside the denominator, and stage
/// names carry their source.
@Suite("Sleep information stage composition (B6)")
struct SleepInformationViewTests {

    @Test("Every asleep stage appears in the breakdown, so none can silently vanish")
    func compositionCoversEveryAsleepStage() {
        let asleepStages = Set(SleepStageType.allCases).subtracting([.awake])
        #expect(Set(SleepInformationView.compositionStageOrder) == asleepStages)
    }

    @Test("Awake is never part of the stage composition")
    func compositionExcludesAwake() {
        #expect(!SleepInformationView.compositionStageOrder.contains(.awake))
    }

    @Test("Unspecified asleep keeps its own row rather than being folded into a stage")
    func compositionPreservesUnspecifiedAsleep() {
        #expect(SleepInformationView.compositionStageOrder.contains(.asleepUnspecified))
    }

    @Test("Apple Health sessions name the N1/N2 stage Core, Zeez sessions do not")
    func stageNamesCarryTheirSource() {
        #expect(SleepStageType.lightSleep.displayName(reportedByAppleHealth: true) == "Core Sleep")
        #expect(SleepStageType.lightSleep.displayName(reportedByAppleHealth: false) == "Light Sleep")
    }

    @Test("Unspecified asleep is never renamed to a specific stage, whatever the source")
    func unspecifiedIsNeverRenamed() {
        for reported in [true, false] {
            let name = SleepStageType.asleepUnspecified.displayName(reportedByAppleHealth: reported)
            #expect(name == "Asleep (Unspecified)")
            for forbidden in ["Core", "Light", "Deep", "REM"] {
                #expect(!name.contains(forbidden))
            }
        }
    }
}
