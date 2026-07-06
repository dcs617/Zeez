import Foundation
import os.log

enum DeveloperSettings {
    @UserDefault(key: "dev_showPremiumFeatures", defaultValue: false)
    static var showPremiumFeatures: Bool
    
    @UserDefault(key: "dev_enableAlarmDebugging", defaultValue: false)
    static var enableAlarmDebugging: Bool
    
    @UserDefault(key: "dev_showAlarmFollowUps", defaultValue: false)
    static var showAlarmFollowUps: Bool
    
    @UserDefault(key: "dev_alarmTestCadence", defaultValue: 10)
    static var alarmTestCadence: Int // seconds for test notifications
    
    // Add more developer settings here as needed
}

@propertyWrapper
struct UserDefault<T> {
    let key: String
    let defaultValue: T
    
    init(key: String, defaultValue: T) {
        self.key = key
        self.defaultValue = defaultValue
    }
    
    var wrappedValue: T {
        get {
            UserDefaults.standard.object(forKey: key) as? T ?? defaultValue
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }
}
