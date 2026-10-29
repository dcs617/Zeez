import SwiftUI
import Combine
import os.log

/// Routes the app's errors to the user or to the log, by `AppError.presentation`.
///
/// `RootView` presents `currentAlert`. Until 2026-10-29 nothing presented these errors at all
/// (`ErrorView` was never applied), so the policy is the decision of that day: alert for a
/// failed save, low storage, a recording that fails to start or end, and the microphone
/// denied when one starts; log the rest. Each alert shows at most once per occurrence: an
/// event once, never stacked behind an identical one, and a condition once until it clears.
final class ErrorManager: ObservableObject {
    static let shared = ErrorManager()

    /// The alert on screen. Main thread only.
    @Published private(set) var currentAlert: AppError?
    /// Alerts waiting for the one on screen, or for the alarm screen, to close.
    private(set) var pendingAlerts: [AppError] = []
    /// Conditions already alerted for their current occurrence, by `AppError.code`.
    private var alertedConditions: Set<String> = []
    /// While the alarm screen is up, alerts wait: a presented alert stops its cover from showing.
    private(set) var isHoldingAlerts = false

    /// Tests use their own instance; the app uses `shared`.
    init() {}

    /// Logs `error`, and queues its alert when the policy says so. Callable from any thread.
    func report(_ error: AppError, file: String = #file, line: Int = #line) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.report(error, file: file, line: line) }
            return
        }
        let fileName = (file as NSString).lastPathComponent
        ZeezLogger.error(ZeezLogger.error, "\(error.code) reported from \(fileName):\(line)")

        guard error.presentation == .alert else { return }
        if error.isCondition {
            guard !alertedConditions.contains(error.code) else { return }
            alertedConditions.insert(error.code)
        }
        guard currentAlert != error, !pendingAlerts.contains(error) else { return }
        pendingAlerts.append(error)
        presentNextIfPossible()
    }

    /// Logs any error; an `AppError` then follows the policy in `report(_:)`.
    func reportError(_ error: Error, file: String = #file, line: Int = #line) {
        if let appError = error as? AppError {
            report(appError, file: file, line: line)
        } else {
            let fileName = (file as NSString).lastPathComponent
            ZeezLogger.error(ZeezLogger.error, "Error reported from \(fileName):\(line)", error: error)
        }
    }

    /// The condition has cleared, so its next occurrence alerts again.
    func clearCondition(_ error: AppError) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.clearCondition(error) }
            return
        }
        alertedConditions.remove(error.code)
    }

    /// The user closed the alert. The next one waits a run-loop turn, so SwiftUI finishes
    /// dismissing this one before it presents another.
    func dismissAlert() {
        currentAlert = nil
        DispatchQueue.main.async { [weak self] in
            self?.presentNextIfPossible()
        }
    }

    /// The alarm screen is about to present: take any alert down and keep it for later.
    func holdAlerts() {
        isHoldingAlerts = true
        if let current = currentAlert {
            pendingAlerts.insert(current, at: 0)
            currentAlert = nil
        }
    }

    /// The alarm screen has closed.
    func releaseAlerts() {
        isHoldingAlerts = false
        presentNextIfPossible()
    }

    private func presentNextIfPossible() {
        guard !isHoldingAlerts, currentAlert == nil, !pendingAlerts.isEmpty else { return }
        currentAlert = pendingAlerts.removeFirst()
    }
}
