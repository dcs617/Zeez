import UIKit
import os.log

class ResourceMonitor {
    
    struct ResourceStatus {
        let batteryLevel: Float
        let thermalState: ProcessInfo.ThermalState
        let lowPowerModeEnabled: Bool
        let availableMemory: UInt64
        let availableStorage: UInt64
        
        var canContinueMonitoring: Bool {
            return batteryLevel > 0.15 && 
                   thermalState != .critical &&
                   availableMemory > 50_000_000 // 50MB
        }
        
        var canProcessData: Bool {
            return batteryLevel > 0.10 &&
                   thermalState != .critical &&
                   availableMemory > 100_000_000 && // 100MB
                   availableStorage > 50_000_000 // 50MB
        }
    }
    
    private var isMonitoring = false
    private let notificationCenter = NotificationCenter.default
    
    init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        startMonitoring()
    }
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        
        // Monitor battery level changes
        notificationCenter.addObserver(
            self,
            selector: #selector(batteryLevelChanged),
            name: UIDevice.batteryLevelDidChangeNotification,
            object: nil
        )
        
        // Monitor battery state changes
        notificationCenter.addObserver(
            self,
            selector: #selector(batteryStateChanged),
            name: UIDevice.batteryStateDidChangeNotification,
            object: nil
        )
        
        // Monitor low power mode
        notificationCenter.addObserver(
            self,
            selector: #selector(powerStateChanged),
            name: .NSProcessInfoPowerStateDidChange,
            object: nil
        )
        
        // Monitor thermal state
        notificationCenter.addObserver(
            self,
            selector: #selector(thermalStateChanged),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )
        
        // Monitor memory warnings
        notificationCenter.addObserver(
            self,
            selector: #selector(memoryWarningReceived),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        notificationCenter.removeObserver(self)
    }
    
    func getCurrentResourceStatus() -> ResourceStatus {
        return ResourceStatus(
            batteryLevel: UIDevice.current.batteryLevel,
            thermalState: ProcessInfo.processInfo.thermalState,
            lowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
            availableMemory: getAvailableMemory(),
            availableStorage: getAvailableStorage()
        )
    }
    
    @objc private func batteryLevelChanged() {
        let level = UIDevice.current.batteryLevel
        ZeezLogger.debug(ZeezLogger.background, "Battery level changed: \(Int(level * 100))%")
        
        if level <= 0.15 {
            ZeezLogger.info(ZeezLogger.background, "Low battery detected - reducing background activity")
        }
    }
    
    @objc private func batteryStateChanged() {
        let state = UIDevice.current.batteryState
        ZeezLogger.debug(ZeezLogger.background, "Battery state changed: \(batteryStateDescription(state))")
    }
    
    @objc private func powerStateChanged() {
        let lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        ZeezLogger.info(ZeezLogger.background, "Low power mode: \(lowPowerMode ? "enabled" : "disabled")")
    }
    
    @objc private func thermalStateChanged() {
        let thermalState = ProcessInfo.processInfo.thermalState
        ZeezLogger.info(ZeezLogger.background, "Thermal state changed: \(thermalStateDescription(thermalState))")
        
        if thermalState == .critical {
            ZeezLogger.info(ZeezLogger.background, "Critical thermal state - pausing intensive operations")
        }
    }
    
    @objc private func memoryWarningReceived() {
        ZeezLogger.info(ZeezLogger.background, "Memory warning received - cleaning up resources")
    }
    
    private func getAvailableMemory() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let totalMemory = ProcessInfo.processInfo.physicalMemory
            let usedMemory = UInt64(info.resident_size)
            return totalMemory > usedMemory ? totalMemory - usedMemory : 0
        }
        
        return 0
    }
    
    private func getAvailableStorage() -> UInt64 {
        guard let documentDirectory = FileManager.default.urls(for: .documentDirectory,
                                                              in: .userDomainMask).first else {
            return 0
        }
        
        do {
            let resourceValues = try documentDirectory.resourceValues(
                forKeys: [.volumeAvailableCapacityForImportantUsageKey]
            )
            return UInt64(resourceValues.volumeAvailableCapacityForImportantUsage ?? 0)
        } catch {
            ZeezLogger.error(ZeezLogger.background, "Failed to get available storage", error: error)
            return 0
        }
    }
    
    private func batteryStateDescription(_ state: UIDevice.BatteryState) -> String {
        switch state {
        case .unknown:
            return "unknown"
        case .unplugged:
            return "unplugged"
        case .charging:
            return "charging"
        case .full:
            return "full"
        @unknown default:
            return "unknown"
        }
    }
    
    private func thermalStateDescription(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal:
            return "nominal"
        case .fair:
            return "fair"
        case .serious:
            return "serious"
        case .critical:
            return "critical"
        @unknown default:
            return "unknown"
        }
    }
    
    deinit {
        stopMonitoring()
        UIDevice.current.isBatteryMonitoringEnabled = false
    }
}