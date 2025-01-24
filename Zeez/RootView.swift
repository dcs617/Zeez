import SwiftUI

/// Root view that handles navigation between onboarding and main app flows
struct RootView: View {
    @StateObject private var onboardingManager = OnboardingManager.shared
    @StateObject private var alarmState = AlarmStateManager.shared
    
    var body: some View {
        ZStack {
            Group {
                if onboardingManager.hasCompletedOnboarding {
                    MainView()
                } else {
                    OnboardingView()
                }
            }
            .withErrorHandling()
            
            // Overlay WakeUpView when alarm is active
            if alarmState.isWaking || alarmState.remainingSnoozeTime != nil {
                Color.black
                    .opacity(0.8)
                    .ignoresSafeArea()
                
                WakeUpView()
                    .transition(.move(edge: .bottom))
            }
        }
        .animation(.spring(), value: alarmState.isWaking)
        .animation(.spring(), value: alarmState.remainingSnoozeTime)
    }
}

#Preview {
    RootView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}