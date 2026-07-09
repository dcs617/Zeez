import Testing
import Foundation

/// Regression guard for the second-audit C1 finding: `SleepControlView.prepareSession`
/// and `SleepSessionManager.startSession` both called `startMonitoring(for:)` on the
/// environmental and movement monitors. The double start was harmless at runtime
/// (`startMonitoring` stops first) but prompted the user for microphone and motion
/// permission twice on the very first session.
///
/// A4 settled the ownership question in the other direction, removing the monitor
/// starts from `BackgroundTaskManager.updateActiveSleepSession`: a `BGAppRefreshTask`
/// cannot run a foreground Timer or mic session, and it handed a background-context
/// `SleepSession` to a monitor that later assigned it into `viewContext`. Monitor
/// lifecycle therefore belongs to exactly one place — the foreground start path, whose
/// single entry point is `SleepSessionManager.startSession`.
///
/// Sources are located relative to `#filePath` so this runs in CI from the same checkout.
struct SessionMonitorLifecycleGuardTests {

    private static var repoRoot: URL {
        // ZeezTests/SessionMonitorLifecycleGuardTests.swift → repo root is one level up.
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func source(_ relative: String) throws -> String {
        try String(contentsOf: Self.repoRoot.appendingPathComponent(relative), encoding: .utf8)
    }

    @Test("SleepSessionManager.startSession owns the monitor start")
    func startSessionStartsMonitors() throws {
        let contents = try source("Zeez/Sleep/SleepSessionManager.swift")
        #expect(contents.contains("EnvironmentalMonitor.shared.startMonitoring"),
                "SleepSessionManager no longer starts the environmental monitor; if ownership moved, update this guard and C1's note rather than deleting the invariant")
        #expect(contents.contains("MovementDataManager.shared.startMonitoring"),
                "SleepSessionManager no longer starts the movement monitor")
    }

    @Test("No other start path starts the monitors a second time")
    func callersDoNotDoubleStart() throws {
        for path in ["Zeez/Sleep/SleepControlView.swift",
                     "Zeez/Infrastructure/BackgroundTaskManager.swift"] {
            #expect(!(try source(path)).contains("startMonitoring"),
                    "\(path) starts a sleep monitor. startSession already does — a second start re-prompts for permissions (C1), and from a background context it assigns across contexts (A4)")
        }
    }
}
