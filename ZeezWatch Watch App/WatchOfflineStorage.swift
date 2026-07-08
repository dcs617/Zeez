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
        return WatchSleepSummary(payload: data)
    }
    
    func cacheAlarmStatus(_ data: [String: Any]) {
        userDefaults.set(data, forKey: Keys.alarmStatus)
    }
    
    func getCachedAlarmStatus() -> WatchAlarmStatus? {
        guard let data = userDefaults.object(forKey: Keys.alarmStatus) as? [String: Any] else {
            return nil
        }
        return WatchAlarmStatus(payload: data)
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
