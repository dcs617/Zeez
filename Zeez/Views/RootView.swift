import SwiftUI
import CoreData
import os.log

struct RootView: View {
    @StateObject private var onboardingManager = OnboardingManager.shared
    @State private var activeAlarm: AlarmConfiguration?
    @State private var showingActiveAlarm = false
    
    var body: some View {
        Group {
            if onboardingManager.hasCompletedOnboarding {
                MainView()
                    .accessibilityIdentifier("mainAppView")
            } else {
                OnboardingView()
                    .accessibilityIdentifier("onboardingView")
            }
        }
        .accessibilityIdentifier("rootView")
        .fullScreenCover(isPresented: $showingActiveAlarm) {
            if let alarm = activeAlarm {
                ActiveAlarmView(
                    alarm: alarm,
                    onSnooze: {
                        handleSnooze(alarm)
                    },
                    onDismiss: {
                        handleDismiss(alarm)
                    }
                )
                .onAppear {
                    ZeezLogger.info(ZeezLogger.alarm, "📱 Full-screen alarm presented")
                }
            } else {
                // Fallback in case alarm is nil
                VStack {
                    Text("Alarm Error")
                        .foregroundColor(.white)
                    Button("Close") {
                        showingActiveAlarm = false
                        activeAlarm = nil
                    }
                    .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowActiveAlarm"))) { notification in
            if let alarm = notification.object as? AlarmConfiguration {
                activeAlarm = alarm
                showingActiveAlarm = true
            }
        }
    }
    
    private func handleSnooze(_ alarm: AlarmConfiguration) {
        showingActiveAlarm = false
        activeAlarm = nil // Clear the active alarm reference
        
        // Schedule snooze (9 minutes from now)
        let snoozeTime = Date().addingTimeInterval(9 * 60)
        scheduleSnoozeNotification(for: alarm, at: snoozeTime)
        
        // Ensure UI responsiveness
        DispatchQueue.main.async {
            if UIApplication.shared.applicationState == .active {
                // App should remain responsive
            }
        }
        
        ZeezLogger.info(ZeezLogger.alarm, "Alarm snoozed for 9 minutes")
    }
    
    private func handleDismiss(_ alarm: AlarmConfiguration) {
        showingActiveAlarm = false
        activeAlarm = nil // Clear the active alarm reference
        
        // Ensure we're on the main thread and the UI is responsive
        DispatchQueue.main.async {
            // Force a UI refresh if needed
            if UIApplication.shared.applicationState == .active {
                // App should remain responsive
            }
        }
        
        ZeezLogger.info(ZeezLogger.alarm, "Alarm dismissed")
    }
    
    private func scheduleSnoozeNotification(for alarm: AlarmConfiguration, at time: Date) {
        let content = UNMutableNotificationContent()
        content.title = alarm.name ?? "Alarm"
        content.body = "Snooze time's up!"
        content.sound = .defaultCritical // Use reliable critical alert sound
        
        let timeInterval = time.timeIntervalSinceNow
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "snooze-\(alarm.id?.uuidString ?? UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                ZeezLogger.error(ZeezLogger.alarm, "Failed to schedule snooze", error: error)
            }
        }
    }
}

#if DEBUG
struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
#endif
