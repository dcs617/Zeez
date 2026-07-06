import Testing
import Foundation
@testable import Zeez

/// Encode/decode round-trips for the phone↔watch wire models (roadmap 2.4
/// step 4). Both targets compile the same Shared/WatchDataModels.swift, but
/// the encoded JSON and the enum raw values ARE the wire contract — breaking
/// them breaks phone↔watch messaging between app versions.
@Suite("Watch model round-trips")
struct WatchModelRoundTripTests {

    private func roundTrip<T: Codable>(_ value: T) throws -> T {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(T.self, from: data)
    }

    @Test func sleepSummaryRoundTripsAllFields() throws {
        let bed = Date(timeIntervalSince1970: 1_750_000_000)
        let wake = bed.addingTimeInterval(7.5 * 3600)
        let summary = WatchSleepSummary(duration: 7.5 * 3600, quality: 87.5,
                                        qualityAvailable: true, bedTime: bed, wakeTime: wake)

        let decoded = try roundTrip(summary)
        #expect(decoded.lastNightDuration == summary.lastNightDuration)
        #expect(decoded.qualityScore == summary.qualityScore)
        #expect(decoded.bedTime == summary.bedTime)
        #expect(decoded.wakeTime == summary.wakeTime)
        #expect(decoded.isDataAvailable == summary.isDataAvailable)
        #expect(decoded.isQualityScoreAvailable == summary.isQualityScoreAvailable)
    }

    @Test func alarmStatusRoundTripsAllFields() throws {
        let status = WatchAlarmStatus(time: Date(timeIntervalSince1970: 1_760_000_000),
                                      enabled: true, smartWake: true, window: 25, name: "Weekday")

        let decoded = try roundTrip(status)
        #expect(decoded.nextAlarmTime == status.nextAlarmTime)
        #expect(decoded.isEnabled == status.isEnabled)
        #expect(decoded.smartWakeEnabled == status.smartWakeEnabled)
        #expect(decoded.smartWakeWindow == status.smartWakeWindow)
        #expect(decoded.alarmName == status.alarmName)
    }

    @Test func wakePatternRoundTripsIncludingHapticPattern() throws {
        for pattern in HapticPattern.allCases {
            let data = WakePatternData(pattern: pattern, intensity: 0.7, duration: 45)
            let decoded = try roundTrip(data)
            #expect(decoded.pattern == pattern)
            #expect(decoded.intensity == 0.7)
            #expect(decoded.duration == 45)
        }
    }

    @Test func wireEnumRawValuesAreStable() {
        // These strings travel between app versions on two devices — treat
        // any change as a breaking protocol change.
        #expect(WatchMessageType.sleepSummary.rawValue == "sleepSummary")
        #expect(WatchMessageType.alarmStatus.rawValue == "alarmStatus")
        #expect(WatchMessageType.wakePattern.rawValue == "wakePattern")
        #expect(WatchMessageType.stopPattern.rawValue == "stopPattern")
        #expect(WatchMessageType.acknowledge.rawValue == "acknowledge")
        #expect(WatchMessageType.snooze.rawValue == "snooze")
        #expect(WatchMessageType.requestData.rawValue == "requestData")

        #expect(HapticPattern.gentle.rawValue == "gentle")
        #expect(HapticPattern.moderate.rawValue == "moderate")
        #expect(HapticPattern.strong.rawValue == "strong")
    }

    @Test func sleepSummaryDerivedDisplayHelpers() {
        let none = WatchSleepSummary()
        #expect(!none.isDataAvailable)
        #expect(none.qualityDescription == "Not Available")

        let good = WatchSleepSummary(duration: 7 * 3600 + 30 * 60, quality: 85, qualityAvailable: true)
        #expect(good.isDataAvailable)
        #expect(good.formattedDuration == "7h 30m")
        #expect(good.qualityDescription == "Good")
    }
}
