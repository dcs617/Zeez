import Testing
@testable import Zeez

/// `EnvironmentalReading.noiseLevel` stores a relative noise index (0–100) derived from
/// microphone average power in dBFS, never decibels SPL. These vectors pin the mapping
/// and the clamping so a future change cannot silently reintroduce the units fiction.
@Suite("Relative noise index (B5)")
struct NoiseIndexTests {

    @Test("Digital silence maps to the bottom of the index")
    func silenceMapsToZero() {
        #expect(NoiseIndex.fromAveragePower(-160) == 0)
    }

    @Test("Full scale maps to the top of the index")
    func fullScaleMapsToOneHundred() {
        #expect(NoiseIndex.fromAveragePower(0) == 100)
    }

    @Test("Midpoint of the dBFS range maps to the midpoint of the index")
    func midpointMapsToFifty() {
        #expect(abs(NoiseIndex.fromAveragePower(-80) - 50) < 0.0001)
    }

    @Test("Power outside the nominal dBFS range is clamped, never wrapped")
    func outOfRangePowerIsClamped() {
        #expect(NoiseIndex.fromAveragePower(-200) == 0)
        #expect(NoiseIndex.fromAveragePower(40) == 100)
    }

    @Test("The index rises monotonically with loudness")
    func indexRisesWithLoudness() {
        let quiet = NoiseIndex.fromAveragePower(-60)
        let moderate = NoiseIndex.fromAveragePower(-40)
        let loud = NoiseIndex.fromAveragePower(-20)
        #expect(quiet < moderate)
        #expect(moderate < loud)
    }

    @Test("Thresholds are ordered and sit inside the index range")
    func thresholdsAreOrderedAndInRange() {
        #expect(NoiseIndex.quietCeiling < NoiseIndex.elevatedFloor)
        #expect(NoiseIndex.range.contains(NoiseIndex.quietCeiling))
        #expect(NoiseIndex.range.contains(NoiseIndex.elevatedFloor))
    }

    @Test("Mock readings stay on the index scale, not the decibel scale")
    func mockNoiseStaysOnIndexScale() {
        for _ in 0..<200 {
            let base = MockEnvironmentalPatternGenerator.generateBaseReading()
            #expect(NoiseIndex.range.contains(base.noise))
            // A real 20-55 dB SPL value would land far below the quiet room's index.
            #expect(base.noise >= 60)

            let varied = MockEnvironmentalPatternGenerator.addTimeVariation(to: base, at: .now)
            #expect(NoiseIndex.range.contains(varied.noise))
        }
    }

    @Test("The display unit is not a physical unit")
    func displayUnitIsNotDecibels() {
        #expect(!NoiseIndex.displayUnit.lowercased().contains("db"))
    }
}
