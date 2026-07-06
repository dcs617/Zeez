import Foundation

// iOS-only bridge from the Core Data SleepSession to the shared watch model.
// Lives here (not in Shared/WatchDataModels.swift) because the watch target
// compiles the shared file and has no Core Data entities.
extension WatchSleepSummary {
    /// Initialize from Core Data sleep session
    init(from coreDataSession: SleepSession) {
        guard let startTime = coreDataSession.startTime,
              let endTime = coreDataSession.endTime,
              let duration = coreDataSession.derivedSleepMetrics.recordedSessionInterval.value else {
            self.init()
            return
        }

        self.init(
            duration: duration,
            quality: coreDataSession.qualityScore,
            qualityAvailable: coreDataSession.hasDisplayableScore,
            bedTime: startTime,
            wakeTime: endTime
        )
    }
}
