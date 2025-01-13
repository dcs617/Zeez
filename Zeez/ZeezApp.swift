import SwiftUI

@main
struct ZeezApp: App {
    // Register our app delegate
    @UIApplicationDelegateAdaptor(ApplicationDelegate.self) var appDelegate
    
    // Initializing our Core Data stack
    let persistenceController = PersistenceController.shared
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
