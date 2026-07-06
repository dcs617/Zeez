import UIKit
import SwiftUI
import os.log

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    let backgroundTaskManager = BackgroundTaskManager.shared
    let errorManager = ErrorManager.shared
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        
        let rootView = RootView()
            .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
        
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: rootView)
        self.window = window
        window.makeKeyAndVisible()
    }
    
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
