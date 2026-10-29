import UIKit
import CoreData
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
            // Log only: there is nothing the user could do about it.
            if let error = error {
                ZeezLogger.error(ZeezLogger.app, "Badge reset failed", error: error)
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
        Self.saveIfNeeded(PersistenceController.shared.container.viewContext, reportingTo: errorManager)
    }

    /// A failed save alerts: the user's last change may be lost. It used to go to
    /// `reportError`, which presented only `AppError`s, so a Core Data error reached no one.
    static func saveIfNeeded(_ context: NSManagedObjectContext, reportingTo errors: ErrorManager) {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            ZeezLogger.error(ZeezLogger.coreData, "viewContext save failed", error: error)
            errors.report(.saveFailed)
        }
    }
}
