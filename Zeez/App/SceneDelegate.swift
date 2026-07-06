import UIKit
import os.log

/// Scene-lifecycle hooks only. The window and root view come from ZeezApp's
/// WindowGroup — creating a second UIWindow here duplicated the entire live UI
/// hierarchy (two RootViews; caught by ZeezUITests' ambiguous-element failures).
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    let backgroundTaskManager = BackgroundTaskManager.shared
    let errorManager = ErrorManager.shared

    func sceneDidDisconnect(_ scene: UIScene) {
        saveCoreDataContext()
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        backgroundTaskManager.checkBatteryAndStorage()
        UNUserNotificationCenter.current().setBadgeCount(0) { error in
            if let error = error {
                self.errorManager.reportError(error)
            }
        }
    }

    func sceneWillResignActive(_ scene: UIScene) {
        saveCoreDataContext()
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        backgroundTaskManager.scheduleSleepUpdate()
        backgroundTaskManager.scheduleDataProcessing()
        saveCoreDataContext()
    }
    
    private func saveCoreDataContext() {
        let context = PersistenceController.shared.container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                errorManager.reportError(error)
            }
        }
    }
}
