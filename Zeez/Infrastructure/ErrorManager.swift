import SwiftUI
import Combine
import os.log

/// Manages error and status states throughout the app
final class ErrorManager: ObservableObject {
    static let shared = ErrorManager()
    
    @Published var currentError: AppError?
    @Published var isShowingError = false
    @Published private(set) var statusMessage: String?
    
    private var errorCancellables = Set<AnyCancellable>()
    private var statusDismissalWorkItem: DispatchWorkItem?
    private var errorDismissalWorkItem: DispatchWorkItem?
    
    private init() {
        // Auto-dismiss warnings after 3 seconds
        $currentError
            .compactMap { $0 }
            .filter { $0.isWarning }
            .sink { [weak self] error in
                self?.scheduleErrorDismissal(for: error)
            }
            .store(in: &errorCancellables)
        
        // Clean up on app termination
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }
    
    deinit {
        cleanup()
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func appWillTerminate() {
        cleanup()
    }
    
    /// Clean up all scheduled work items
    private func cleanup() {
        statusDismissalWorkItem?.cancel()
        statusDismissalWorkItem = nil
        errorDismissalWorkItem?.cancel()
        errorDismissalWorkItem = nil
        errorCancellables.removeAll()
    }
    
    /// Reset singleton state for testing
    func reset() {
        cleanup()
        currentError = nil
        isShowingError = false
        statusMessage = nil
    }
    
    /// Schedule error dismissal with proper cleanup
    private func scheduleErrorDismissal(for error: AppError) {
        // Cancel any existing error dismissal
        errorDismissalWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            if self?.currentError == error {
                self?.dismissError()
            }
            self?.errorDismissalWorkItem = nil
        }
        
        errorDismissalWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + AppConstants.UI.extendedNotificationDuration,
            execute: workItem
        )
    }
    
    /// Shows an error to the user
    func showError(_ error: AppError) {
        currentError = error
        isShowingError = true
    }
    
    /// Dismisses the current error
    func dismissError() {
        currentError = nil
        isShowingError = false
    }
    
    /// Shows a status message
    func showStatus(_ message: String) {
        statusMessage = message
        
        // Cancel any existing status dismissal
        statusDismissalWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            if self?.statusMessage == message {
                self?.statusMessage = nil
            }
            self?.statusDismissalWorkItem = nil
        }
        
        statusDismissalWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + AppConstants.UI.notificationDuration,
            execute: workItem
        )
    }
    
    /// Reports an error and logs it for analytics
    func reportError(_ error: Error, file: String = #file, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        ZeezLogger.error(ZeezLogger.error, "Error reported from \(fileName):\(line)", error: error)
        
        // Convert to AppError if possible
        if let appError = error as? AppError {
            showError(appError)
        } else {
            // Log unknown errors for analytics
            ZeezLogger.error(ZeezLogger.error, "Unknown error type: \(type(of: error))")
        }
        
        // TODO: Send to analytics service in production
    }
}