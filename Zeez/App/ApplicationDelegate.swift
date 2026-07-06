import UIKit
import BackgroundTasks
import UserNotifications
import os.log

class ApplicationDelegate: NSObject, UIApplicationDelegate {
    let backgroundTaskManager = BackgroundTaskManager.shared
    private var didRescheduleOnce = false

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        setupBatteryMonitoring()
        
        // 1) Register notification categories + set delegate for the new alarm system
        AlarmNotificationRegistrar.prepare(delegate: AlarmNotificationHandler.shared)
        
        // Background tasks are automatically registered in BackgroundTaskManager.init()
        // Force initialization of the singleton if needed
        _ = backgroundTaskManager
        
        // 2) Conservative reschedule: do it once when app becomes active.
        //    (This avoids tight coupling to Core Data load timing.)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, !self.didRescheduleOnce else { return }
            self.didRescheduleOnce = true
            
            // Reschedule all enabled alarms on first activation after launch
            let context = PersistenceController.shared.container.viewContext
            AlarmScheduler.shared.scheduleAllAlarms(context: context)
            ZeezLogger.info(ZeezLogger.alarm, "🔄 Rescheduled all alarms on first app activation")
        }
        
        return true
    }
    
    private func setupBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}
