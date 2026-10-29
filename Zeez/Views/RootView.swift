import SwiftUI
import CoreData
import os.log

struct RootView: View {
    @StateObject private var onboardingManager = OnboardingManager.shared
    @StateObject private var modalCoordinator = ModalCoordinator.shared
    @StateObject private var permissionManager = AlarmPermissionManager.shared
    @StateObject private var errorManager = ErrorManager.shared
    @State private var activeAlarm: AlarmConfiguration?
    @State private var showingActiveAlarm = false
    @State private var showingPermissionDenied = false
    @State private var showingMigrationDataLossNotice = false
    
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
        .sheet(item: $modalCoordinator.activeModal, onDismiss: {
            // Notify that modal was dismissed - Settings can refresh its data status
            NotificationCenter.default.post(name: .modalDismissed, object: nil)
        }) { modal in
            switch modal {
            case .dataImport:
                SimpleDataImportView()
                    .interactiveDismissDisabled(false)
            }
        }
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
        .onReceive(NotificationCenter.default.publisher(for: .showActiveAlarm)) { notification in
            if let alarm = notification.object as? AlarmConfiguration {
                // Prevent UI conflicts: dismiss any active sheets first
                dismissActiveModals()
                
                // Small delay to ensure dismissal completes before showing alarm
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    activeAlarm = alarm
                    showingActiveAlarm = true
                }
            }
        }
        .overlay {
            // Permission Explainer
            if permissionManager.showPermissionExplainer {
                AlarmPermissionExplainerView(
                    onAllow: {
                        permissionManager.handleExplainerAllow()
                    },
                    onDismiss: {
                        permissionManager.handleExplainerDismiss()
                    }
                )
                .transition(.opacity.animation(.easeInOut))
                .zIndex(1000)
            }
            
            // Permission Denied
            if showingPermissionDenied {
                AlarmPermissionDeniedView(
                    onOpenSettings: {
                        permissionManager.openSettings()
                        showingPermissionDenied = false
                    },
                    onDismiss: {
                        showingPermissionDenied = false
                    }
                )
                .transition(.opacity.animation(.easeInOut))
                .zIndex(1000)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .alarmPermissionDenied)) { _ in
            // Show denied permission flow when user tries to enable alarm without permissions
            if permissionManager.isDenied {
                showingPermissionDenied = true
            }
        }
        .onAppear {
            // One-time notice if a failed migration forced a fresh store (2.6)
            if UserDefaults.standard.bool(forKey: PersistenceController.migrationDataLossNoticeKey) {
                showingMigrationDataLossNotice = true
            }
        }
        // The app's one error alert (ErrorManager decides which errors reach it). It is held
        // while the alarm screen is up: a presented alert would stop the cover from showing.
        .alert(
            errorManager.currentAlert?.errorDescription ?? "",
            isPresented: Binding(
                get: { errorManager.currentAlert != nil },
                set: { if !$0 { errorManager.dismissAlert() } }
            ),
            presenting: errorManager.currentAlert
        ) { error in
            if error.opensSettings {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .accessibilityHint("Opens Zeez's page in Settings")
                Button("Not Now", role: .cancel) {}
                    .accessibilityHint("Closes this message")
            } else {
                Button("OK", role: .cancel) {}
                    .accessibilityHint("Closes this message")
            }
        } message: { error in
            Text(error.recoverySuggestion ?? "")
        }
        .onChange(of: showingActiveAlarm) { _, isShowing in
            if !isShowing {
                errorManager.releaseAlerts()
            }
        }
        .alert("Sleep History Unavailable", isPresented: $showingMigrationDataLossNotice) {
            Button("OK") {
                UserDefaults.standard.removeObject(forKey: PersistenceController.migrationDataLossNoticeKey)
            }
        } message: {
            Text("Your sleep history could not be migrated after an app update, so Zeez started with a fresh database. A backup of your previous data was kept on this device.")
        }
    }
    
    private func handleSnooze(_ alarm: AlarmConfiguration) {
        showingActiveAlarm = false
        activeAlarm = nil // Clear the active alarm reference
        
        // Use the new centralized snooze scheduling
        if let alarmId = alarm.id?.uuidString {
            AlarmNotificationUtils.scheduleSnooze(for: alarmId)
        }
        
        // Ensure UI responsiveness
        DispatchQueue.main.async {
            if UIApplication.shared.applicationState == .active {
                // App should remain responsive
            }
        }
        
        ZeezLogger.info(ZeezLogger.alarm, "Alarm snoozed for \(alarm.snoozeDurationMinutes) minutes")
    }
    
    private func handleDismiss(_ alarm: AlarmConfiguration) {
        showingActiveAlarm = false
        activeAlarm = nil // Clear the active alarm reference

        // The same Stop as the notification's action: without it the follow-ups armed when
        // the alarm fired kept ringing after the alarm screen's Stop.
        if let alarmId = alarm.id?.uuidString {
            AlarmNotificationHandler.shared.stopAlarm(alarmId: alarmId)
        }
        
        // Ensure we're on the main thread and the UI is responsive
        DispatchQueue.main.async {
            // Force a UI refresh if needed
            if UIApplication.shared.applicationState == .active {
                // App should remain responsive
            }
        }
        
        ZeezLogger.info(ZeezLogger.alarm, "Alarm dismissed")
    }
    
    /// Dismiss any active modals to prevent UI conflicts with alarm display
    private func dismissActiveModals() {
        // Dismiss permission explainer
        if permissionManager.showPermissionExplainer {
            permissionManager.handleExplainerDismiss()
        }
        
        // Dismiss permission denied view
        if showingPermissionDenied {
            showingPermissionDenied = false
        }
        
        // Dismiss any modal coordinator sheets
        modalCoordinator.activeModal = nil

        // Take down any error alert, and keep new ones back until the alarm screen closes
        errorManager.holdAlerts()
        
        ZeezLogger.debug(ZeezLogger.alarm, "🔄 Dismissed active modals for alarm display")
    }
    
    // Removed scheduleSnoozeNotification - now handled by AlarmNotificationUtils
}

#if DEBUG
struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
#endif
