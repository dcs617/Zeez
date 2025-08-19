import UIKit
import BackgroundTasks
import os.log

class ApplicationDelegate: NSObject, UIApplicationDelegate {
    let backgroundTaskManager = BackgroundTaskManager.shared

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        setupBatteryMonitoring()
        // Background tasks are automatically registered in BackgroundTaskManager.init()
        // Force initialization of the singleton if needed
        _ = backgroundTaskManager
        return true
    }
    
    private func setupBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}
