import Foundation
import SwiftUI
import Combine

/// Coordinates modal presentations to prevent conflicts and simultaneous presentations
@MainActor
class ModalCoordinator: ObservableObject {
    static let shared = ModalCoordinator()
    
    @Published var activeModal: ModalType?
    @Published private(set) var isTransitioning: Bool = false
    
    private var pendingModal: ModalType?
    private let transitionDelay: TimeInterval = 0.3
    
    private init() {}
    
    enum ModalType: Equatable, Identifiable {
        case dataImport
        case healthKitError
        case settings
        case debug
        
        var id: String {
            switch self {
            case .dataImport: return "dataImport"
            case .healthKitError: return "healthKitError"
            case .settings: return "settings"
            case .debug: return "debug"
            }
        }
    }
    
    func present(_ modal: ModalType, 
                 file: StaticString = #fileID,
                 line: UInt = #line) {
        // If we're already showing this one, do nothing.
        if activeModal == modal {
            print("🔔 ModalCoordinator: \(modal) already active (\(file):\(line))")
            return
        }
        
        // If another modal is up or we're animating, queue and wait.
        guard !isTransitioning, activeModal == nil else {
            print("🔔 ModalCoordinator: Deferring \(modal) while \(String(describing: activeModal)) is active (\(file):\(line))")
            pendingModal = modal
            return
        }
        
        print("🔔 ModalCoordinator: Setting up presentation for \(modal)")
        isTransitioning = true
        activeModal = modal
        
        // Clear the transition flag shortly after, once SwiftUI binds.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            self.isTransitioning = false
            print("🔔 ModalCoordinator: Successfully presented \(modal)")
        }
    }
    
    func dismiss(completion: (() -> Void)? = nil) {
        guard activeModal != nil else { 
            completion?() 
            return 
        }
        
        print("🔔 ModalCoordinator: Dismissing \(String(describing: activeModal))")
        isTransitioning = true
        activeModal = nil
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isTransitioning = false
            print("🔔 ModalCoordinator: Dismiss completed")
            if let next = self.pendingModal {
                self.pendingModal = nil
                self.present(next)
            }
            completion?()
        }
    }
    
    func isPresenting(_ modal: ModalType) -> Bool {
        let result = activeModal == modal
        print("🔔 ModalCoordinator: isPresenting(\(modal)) -> \(result) (activeModal: \(String(describing: activeModal)))")
        return result
    }
    
    func canPresent() -> Bool {
        activeModal == nil && !isTransitioning
    }
}