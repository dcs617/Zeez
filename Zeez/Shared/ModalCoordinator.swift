import Foundation
import SwiftUI
import Combine
import os.log

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

        var id: String {
            switch self {
            case .dataImport: return "dataImport"
            }
        }
    }
    
    func present(_ modal: ModalType, 
                 file: StaticString = #fileID,
                 line: UInt = #line) {
        // If we're already showing this one, do nothing.
        if activeModal == modal {
            ZeezLogger.debug(ZeezLogger.ui, "🔔 ModalCoordinator: \(modal) already active (\(file):\(line))")
            return
        }

        // If another modal is up or we're animating, queue and wait.
        guard !isTransitioning, activeModal == nil else {
            ZeezLogger.debug(ZeezLogger.ui, "🔔 ModalCoordinator: Deferring \(modal) while \(String(describing: activeModal)) is active (\(file):\(line))")
            pendingModal = modal
            return
        }

        ZeezLogger.debug(ZeezLogger.ui, "🔔 ModalCoordinator: Setting up presentation for \(modal)")
        isTransitioning = true
        activeModal = modal

        // Clear the transition flag shortly after, once SwiftUI binds.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            self.isTransitioning = false
            ZeezLogger.debug(ZeezLogger.ui, "🔔 ModalCoordinator: Successfully presented \(modal)")
        }
    }
    
    func dismiss(completion: (() -> Void)? = nil) {
        guard activeModal != nil else { 
            completion?() 
            return 
        }
        
        ZeezLogger.debug(ZeezLogger.ui, "🔔 ModalCoordinator: Dismissing \(String(describing: activeModal))")
        isTransitioning = true
        activeModal = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isTransitioning = false
            ZeezLogger.debug(ZeezLogger.ui, "🔔 ModalCoordinator: Dismiss completed")
            if let next = self.pendingModal {
                self.pendingModal = nil
                self.present(next)
            }
            completion?()
        }
    }
    
    func isPresenting(_ modal: ModalType) -> Bool {
        activeModal == modal
    }
    
    func canPresent() -> Bool {
        activeModal == nil && !isTransitioning
    }
}