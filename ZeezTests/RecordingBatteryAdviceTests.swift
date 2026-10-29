import Testing
import UIKit
@testable import Zeez

/// The charger suggestion when a recording runs on battery (decision 2026-10-29): soft on an
/// unplugged phone, stronger at or below 30%, and nothing at all when charging or unknown.
/// The recording screen it replaces showed a battery percentage and no advice.
@Suite("Recording battery advice")
struct RecordingBatteryAdviceTests {

    @Test("An unplugged phone gets the soft suggestion")
    func unpluggedGetsSoftSuggestion() {
        let message = RecordingBatteryAdvice.message(state: .unplugged, level: 0.8)
        #expect(message == "Recording all night uses battery. Plug in your phone if you can.")
    }

    @Test("At or below 30% the message names the level and the alarm")
    func lowBatteryGetsStrongerLine() throws {
        let atThreshold = try #require(RecordingBatteryAdvice.message(state: .unplugged, level: 0.30))
        #expect(atThreshold.contains("30%"))
        #expect(atThreshold.contains("alarm"))

        let below = try #require(RecordingBatteryAdvice.message(state: .unplugged, level: 0.24))
        #expect(below.contains("24%"))
    }

    @Test("Just above 30% stays soft")
    func justAboveThresholdStaysSoft() {
        let message = RecordingBatteryAdvice.message(state: .unplugged, level: 0.31)
        #expect(message?.contains("%") == false)
    }

    @Test("Charging or full says nothing")
    func chargingSaysNothing() {
        #expect(RecordingBatteryAdvice.message(state: .charging, level: 0.1) == nil)
        #expect(RecordingBatteryAdvice.message(state: .full, level: 1.0) == nil)
    }

    @Test("An unknown battery (the simulator) says nothing, rather than a made-up level")
    func unknownSaysNothing() {
        #expect(RecordingBatteryAdvice.message(state: .unknown, level: -1) == nil)
        #expect(RecordingBatteryAdvice.message(state: .unplugged, level: -1) == nil)
    }
}
