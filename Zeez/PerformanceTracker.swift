import Foundation
import SwiftUI

/// Tracks app performance metrics
class PerformanceTracker {
    static let shared = PerformanceTracker()
    
    private var operations: [String: CFTimeInterval] = [:]
    private var memorySnapshots: [Date: Double] = [:]
    private let analytics = AnalyticsManager.shared
    
    private init() {
        startPeriodicMemoryTracking()
    }
    
    // MARK: - Operation Tracking
    
    func startOperation(_ name: String) {
        operations[name] = CACurrentMediaTime()
    }
    
    func endOperation(_ name: String, wasSuccessful: Bool = true) {
        guard let startTime = operations[name] else { return }
        
        let duration = CACurrentMediaTime() - startTime
        operations.removeValue(forKey: name)
        
        let metric = PerformanceMetric.operation(
            name,
            duration: duration,
            success: wasSuccessful
        )
        analytics.trackPerformance(metric)
    }
    
    // MARK: - View Performance
    
    func trackViewAppearance<V: View>(_ view: V) -> some View {
        let viewName = String(describing: type(of: view))
        return view.modifier(ViewLoadingTracker(viewName: viewName))
    }
    
    // MARK: - Background Tasks
    
    func trackBackgroundTask(_ name: String, completion: @escaping () -> Void) {
        let startTime = CACurrentMediaTime()
        
        completion()
        
        let duration = CACurrentMediaTime() - startTime
        let metric = PerformanceMetric(
            name: "background_task",
            duration: duration,
            success: true,
            context: name
        )
        analytics.trackPerformance(metric)
    }
    
    // MARK: - Memory Tracking
    
    private func startPeriodicMemoryTracking() {
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.takeMemorySnapshot()
        }
    }
    
    private func takeMemorySnapshot() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }
        
        if kerr == KERN_SUCCESS {
            let usedMB = Double(info.resident_size) / 1024.0 / 1024.0
            memorySnapshots[Date()] = usedMB
            
            // Keep only last hour of snapshots
            let hourAgo = Date().addingTimeInterval(-3600)
            memorySnapshots = memorySnapshots.filter { $0.key > hourAgo }
            
            let metric = PerformanceMetric(
                name: "memory_usage",
                duration: 0,
                success: true,
                context: "\(Int(usedMB))MB"
            )
            analytics.trackPerformance(metric)
        }
    }
    
    // MARK: - Error Rate Tracking
    
    func trackErrorRate(for category: String) -> Double {
        // Calculate error rate based on AnalyticsEvent entries
        // This will be implemented when we add error tracking
        return 0.0
    }
}

// MARK: - View Modifier

struct ViewLoadingTracker: ViewModifier {
    let viewName: String
    @State private var loadStartTime: CFTimeInterval?
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                loadStartTime = CACurrentMediaTime()
            }
            .onDisappear {
                if let startTime = loadStartTime {
                    let duration = CACurrentMediaTime() - startTime
                    let metric = PerformanceMetric.viewLoad(viewName, duration: duration)
                    AnalyticsManager.shared.trackPerformance(metric)
                }
            }
    }
}

// MARK: - Convenience Extensions

extension View {
    func trackPerformance() -> some View {
        PerformanceTracker.shared.trackViewAppearance(self)
    }
}