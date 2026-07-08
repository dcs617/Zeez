import Testing
import Foundation
@testable import Zeez

/// Wire-SHAPE contract tests for phone→watch data updates (second audit A5).
///
/// `WatchModelRoundTripTests` covers the Codable models; this suite covers the
/// actual WCSession dictionaries. The A5 bug: the phone flattened payload
/// fields into the top-level message while the watch only parsed the nested
/// `sleepSummary`/`alarmStatus` keys, so every push was silently dropped.
/// Both sides now speak `WatchSyncEnvelope`; these tests pin that shape.
@Suite("Watch wire contract (A5)")
struct WatchWireContractTests {

    private func makeSummary() -> WatchSleepSummary {
        WatchSleepSummary(
            duration: 7.5 * 3600,
            quality: 82,
            qualityAvailable: true,
            bedTime: Date(timeIntervalSince1970: 1_750_000_000),
            wakeTime: Date(timeIntervalSince1970: 1_750_000_000 + 7.5 * 3600)
        )
    }

    private func makeAlarmStatus() -> WatchAlarmStatus {
        WatchAlarmStatus(
            time: Date(timeIntervalSince1970: 1_760_000_000),
            enabled: true, smartWake: true, window: 25, name: "Weekday"
        )
    }

    // MARK: - Envelope shape

    @Test("Envelope nests payloads under the contract keys, never at top level")
    func envelopeNestsPayloads() {
        let dict = WatchSyncEnvelope(sleepSummary: makeSummary(), alarmStatus: makeAlarmStatus())
            .toDictionary()

        #expect(dict[WatchSyncEnvelope.sleepSummaryKey] is [String: Any])
        #expect(dict[WatchSyncEnvelope.alarmStatusKey] is [String: Any])
        // Payload fields must not leak to the top level (the A5 flattening bug).
        #expect(dict[WatchSleepSummary.WireKey.duration] == nil)
        #expect(dict[WatchAlarmStatus.WireKey.enabled] == nil)
    }

    @Test("Envelope round-trips both payloads through the wire dictionaries")
    func envelopeRoundTrips() {
        let sent = WatchSyncEnvelope(sleepSummary: makeSummary(), alarmStatus: makeAlarmStatus())
        let received = WatchSyncEnvelope(dictionary: sent.toDictionary())

        let summary = received.sleepSummary
        #expect(summary?.lastNightDuration == 7.5 * 3600)
        #expect(summary?.qualityScore == 82)
        #expect(summary?.isQualityScoreAvailable == true)
        #expect(summary?.bedTime == Date(timeIntervalSince1970: 1_750_000_000))
        #expect(summary?.wakeTime == Date(timeIntervalSince1970: 1_750_000_000 + 7.5 * 3600))

        let alarm = received.alarmStatus
        #expect(alarm?.nextAlarmTime == Date(timeIntervalSince1970: 1_760_000_000))
        #expect(alarm?.isEnabled == true)
        #expect(alarm?.smartWakeEnabled == true)
        #expect(alarm?.smartWakeWindow == 25)
        #expect(alarm?.alarmName == "Weekday")
    }

    @Test("Wire dictionaries contain only property-list types (WCSession requirement)")
    func envelopeIsPropertyListSafe() {
        let dict = WatchSyncEnvelope(sleepSummary: makeSummary(), alarmStatus: makeAlarmStatus())
            .toDictionary()
        #expect(PropertyListSerialization.propertyList(dict, isValidFor: .binary),
                "WCSession rejects non-plist values; the envelope must stay plist-safe")
    }

    // MARK: - Push path (the A5 regression)

    @Test("A pushed sleep-summary message decodes on the watch parser's envelope")
    func pushedSleepSummaryIsParseable() throws {
        // Exactly what syncSleepData builds and performSend transmits.
        let message = WatchMessage(
            type: .sleepSummary,
            data: WatchSyncEnvelope(sleepSummary: makeSummary()).toDictionary(),
            priority: .medium
        )
        let wire = try message.toDictionary()

        // Routing metadata at top level…
        #expect(wire["command"] as? String == WatchMessageType.sleepSummary.rawValue)
        // …payload nested where handleDataUpdate reads it.
        let received = WatchSyncEnvelope(dictionary: wire)
        #expect(received.sleepSummary?.lastNightDuration == 7.5 * 3600)
        #expect(received.sleepSummary?.qualityScore == 82)
    }

    @Test("A pushed alarm-status message decodes on the watch parser's envelope")
    func pushedAlarmStatusIsParseable() throws {
        let message = WatchMessage(
            type: .alarmStatus,
            data: WatchSyncEnvelope(alarmStatus: makeAlarmStatus()).toDictionary(),
            priority: .medium
        )
        let wire = try message.toDictionary()

        #expect(wire["command"] as? String == WatchMessageType.alarmStatus.rawValue)
        let received = WatchSyncEnvelope(dictionary: wire)
        #expect(received.alarmStatus?.smartWakeWindow == 25)
        #expect(received.alarmStatus?.isEnabled == true)
    }

    @Test("A legacy flattened message decodes as empty, not as fabricated defaults")
    func flattenedLegacyMessageDecodesEmpty() {
        // The pre-A5 wire shape: payload fields at top level.
        let legacy: [String: Any] = [
            "command": WatchMessageType.sleepSummary.rawValue,
            "duration": 7.5 * 3600,
            "quality": 82.0,
            "qualityAvailable": true
        ]
        let received = WatchSyncEnvelope(dictionary: legacy)
        #expect(received.isEmpty,
                "Flattened payloads must not half-decode into a summary with fabricated fields")
    }

    // MARK: - Missing-score policy on the wire

    @Test("An unavailable score never carries a quality value on the wire")
    func unavailableScoreOmitsQualityKey() {
        let summary = WatchSleepSummary(duration: 6 * 3600, quality: 0, qualityAvailable: false)
        let payload = summary.toPayload()

        #expect(payload[WatchSleepSummary.WireKey.qualityAvailable] as? Bool == false)
        #expect(payload[WatchSleepSummary.WireKey.quality] == nil,
                "Claims rule 4: a missing score must not travel as a neutral-looking number")

        let decoded = WatchSleepSummary(payload: payload)
        #expect(!decoded.isQualityScoreAvailable)
        #expect(decoded.qualityDescription == "Not Available")
    }

    @Test("Alarm payload without a time decodes as no upcoming alarm")
    func alarmWithoutTimeDecodesAsNone() {
        let payload = WatchAlarmStatus(time: nil, enabled: false).toPayload()
        #expect(payload[WatchAlarmStatus.WireKey.time] == nil)

        let decoded = WatchAlarmStatus(payload: payload)
        #expect(decoded.nextAlarmTime == nil)
        #expect(!decoded.isEnabled)
    }
}
