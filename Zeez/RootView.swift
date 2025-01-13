import SwiftUI

/// Root view that handles navigation between onboarding and main app flows
struct RootView: View {
    @StateObject private var onboardingManager = OnboardingManager.shared
    
    var body: some View {
        Group {
            if onboardingManager.hasCompletedOnboarding {
                MainView()
            } else {
                OnboardingView()
            }
        }
        // Apply error handling to both flows
        .withErrorHandling()
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}