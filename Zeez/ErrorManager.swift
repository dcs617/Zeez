import SwiftUI
import Combine

/// Manages error and status states throughout the app
final class ErrorManager: ObservableObject {
    static let shared = ErrorManager()
    
    @Published var currentError: AppError?
    @Published var isShowingError = false
    @Published private(set) var statusMessage: String?
    
    private var errorCancellables = Set<AnyCancellable>()
    
    private init() {
        // Auto-dismiss warnings after 3 seconds
        $currentError
            .compactMap { $0 }
            .filter { $0.isWarning }
            .sink { [weak self] error in
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    if self?.currentError == error {
                        self?.dismissError()
                    }
                }
            }
            .store(in: &errorCancellables)
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
        
        // Auto-dismiss status after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            if self?.statusMessage == message {
                self?.statusMessage = nil
            }
        }
    }
    
    /// Reports an error and logs it for analytics
    func reportError(_ error: Error, file: String = #file, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        print("Error reported from \(fileName):\(line) - \(error.localizedDescription)")
        
        // Convert to AppError if possible
        if let appError = error as? AppError {
            showError(appError)
        } else {
            // Log unknown errors for analytics
            print("Unknown error type: \(type(of: error))")
        }
        
        // TODO: Send to analytics service in production
    }
}