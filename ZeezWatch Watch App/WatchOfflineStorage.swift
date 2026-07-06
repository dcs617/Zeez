import Foundation

// Offline cache used by WatchConnectivityManager while the phone is
// unreachable. Extracted from the deleted EnhancedWatchConnectivityManager
// (the storage was live; the Enhanced connectivity stack around it was not).


struct OfflineAction: Codable {
    enum ActionType: String, Codable {
        case acknowledge
        case snooze
        case requestData
    }
    
    let type: ActionType
    let timestamp: Date
    let id: UUID
    
    init(type: ActionType, timestamp: Date) {
        self.type = type
        self.timestamp = timestamp
        self.id = UUID()
    }
}

// MARK: - Offline Storage

class WatchOfflineStorage {
    private let userDefaults = UserDefaults.standard
    
    private enum Keys {
        static let sleepSummary = "watchSleepSummary"
        static let alarmStatus = "watchAlarmStatus"
        static let lastSyncTime = "watchLastSyncTime"
        static let pendingActions = "watchPendingActions"
    }
    
    func cacheSleepSummary(_ data: [String: Any]) {
        userDefaults.set(data, forKey: Keys.sleepSummary)
    }
    
    func getCachedSleepSummary() -> WatchSleepSummary? {
        guard let data = userDefaults.object(forKey: Keys.sleepSummary) as? [String: Any] else {
            return nil
        }
        
        let duration = data["duration"] as? TimeInterval ?? 0
        let quality = data["quality"] as? Double ?? 0
        let qualityAvailable = data["qualityAvailable"] as? Bool ?? false
        let bedTime = (data["bedTime"] as? TimeInterval).map { Date(timeIntervalSince1970: $0) }
        let wakeTime = (data["wakeTime"] as? TimeInterval).map { Date(timeIntervalSince1970: $0) }
        
        return WatchSleepSummary(duration: duration, quality: quality, qualityAvailable: qualityAvailable, bedTime: bedTime, wakeTime: wakeTime)
    }
    
    func cacheAlarmStatus(_ data: [String: Any]) {
        userDefaults.set(data, forKey: Keys.alarmStatus)
    }
    
    func getCachedAlarmStatus() -> WatchAlarmStatus? {
        guard let data = userDefaults.object(forKey: Keys.alarmStatus) as? [String: Any] else {
            return nil
        }
        
        let timeInterval = data["time"] as? TimeInterval
        let nextTime = timeInterval.map { Date(timeIntervalSince1970: $0) }
        let enabled = data["enabled"] as? Bool ?? false
        let smartWake = data["smartWake"] as? Bool ?? false
        let window = data["smartWakeWindow"] as? Int ?? 30
        let name = data["name"] as? String ?? "Alarm"
        
        return WatchAlarmStatus(time: nextTime, enabled: enabled, smartWake: smartWake, window: window, name: name)
    }
    
    func updateLastSyncTime(_ date: Date) {
        userDefaults.set(date.timeIntervalSince1970, forKey: Keys.lastSyncTime)
    }
    
    func getLastSyncTime() -> Date? {
        let timestamp = userDefaults.double(forKey: Keys.lastSyncTime)
        return timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
    }
    
    func addPendingAction(_ action: OfflineAction) {
        var actions = getPendingActions()
        actions.append(action)
        
        if let data = try? JSONEncoder().encode(actions) {
            userDefaults.set(data, forKey: Keys.pendingActions)
        }
    }
    
    func getPendingActions() -> [OfflineAction] {
        guard let data = userDefaults.data(forKey: Keys.pendingActions),
              let actions = try? JSONDecoder().decode([OfflineAction].self, from: data) else {
            return []
        }
        return actions
    }
    
    func clearPendingActions() {
        userDefaults.removeObject(forKey: Keys.pendingActions)
    }
}
