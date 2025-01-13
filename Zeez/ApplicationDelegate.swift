import UIKit
import BackgroundTasks

class ApplicationDelegate: NSObject, UIApplicationDelegate {
    let backgroundTaskManager = BackgroundTaskManager.shared

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        setupBackgroundTasks()
        setupBatteryMonitoring()
        return true
    }
    
    private func setupBackgroundTasks() {
        backgroundTaskManager.registerBackgroundTasks()
    }
    
    private func setupBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}