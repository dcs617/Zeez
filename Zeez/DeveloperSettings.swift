import Foundation

enum DeveloperSettings {
    @UserDefault(key: "dev_showPremiumFeatures", defaultValue: false)
    static var showPremiumFeatures: Bool
    
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
