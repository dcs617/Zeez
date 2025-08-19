import SwiftUI
import os.log

struct OnboardingView: View {
    @StateObject private var manager = OnboardingManager.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                OnboardingProgressView(currentStep: manager.currentStep)
                    .padding(.top)
                
                ScrollView {
                    LazyVStack {
                        switch manager.currentStep {
                        case .welcome:
                            welcomeContent
                        case .healthKit:
                            healthKitContent
                        case .notifications:
                            notificationsContent
                        case .watchPairing:
                            watchPairingContent
                        case .sleepGoal:
                            sleepGoalContent
                        case .completion:
                            completionContent
                        }
                    }
                    .animation(.easeInOut, value: manager.currentStep)
                    .transition(OnboardingAnimation.slideTransition)
                }
                
                Spacer()
                
                OnboardingButton(
                    title: manager.currentStep == .completion ? "Get Started" : "Continue",
                    action: { manager.moveToNextStep() },
                    isLoading: manager.isTransitioning
                )
                .padding(.horizontal)
            }
            .padding()
            .adaptiveNavigationBar()
            .alert("Attention Required", isPresented: $manager.showErrorAlert) {
                Button("OK", role: .cancel) {}
                if manager.activeError == .healthKitPermissionDenied ||
                    manager.activeError == .notificationsPermissionDenied {
                    Button("Open Settings") {
                        #if os(iOS)
                        manager.openSettings()
                        #endif
                    }
                }
            } message: {
                if let error = manager.activeError {
                    VStack(alignment: .leading) {
                        Text(error.errorDescription ?? "")
                        if let recovery = error.recoverySuggestion {
                            Text(recovery)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
    
    private var welcomeContent: some View {
        VStack(spacing: 24) {
            Image(systemName: manager.currentStep.systemImage)
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
                .symbolEffect(.bounce, options: .repeat(2))
                .accessibilityHidden(true)
            
            Text(manager.currentStep.title)
                .font(.title)
                .bold()
                .multilineTextAlignment(.center)
            
            Text(manager.currentStep.description)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            VStack(spacing: 16) {
                PermissionRow("Track sleep duration and quality")
                PermissionRow("Monitor heart rate during sleep")
                PermissionRow("Get personalized recommendations")
            }
            .onboardingCard()
        }
        .padding()
    }
    
    private var healthKitContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 80))
                .foregroundColor(.red)
                .symbolEffect(.pulse)
                .accessibilityHidden(true)
            
            Text("Health Integration Features:")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                PermissionRow("Track sleep duration and quality", isGranted: manager.healthKitAuthorized)
                    .accessibilityHint("Allows Zeez to read and write your sleep data in Apple Health")
                
                PermissionRow("Monitor heart rate during sleep", isGranted: manager.healthKitAuthorized)
                    .accessibilityHint("Enables heart rate tracking during sleep for better sleep stage detection")
                
                PermissionRow("Record respiratory rate", isGranted: manager.healthKitAuthorized)
                    .accessibilityHint("Tracks breathing rate to identify potential sleep disturbances")
            }
            .onboardingCard()
            
            if manager.healthKitAuthorized {
                Label("Health Access Granted", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding()
    }
    
    private var notificationsContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.badge")
                .font(.system(size: 80))
                .foregroundColor(.blue)
                .symbolEffect(.bounce)
                .accessibilityHidden(true)
            
            Text("Notification Features:")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                PermissionRow("Smart bedtime reminders", isGranted: manager.notificationsAuthorized)
                PermissionRow("Sleep quality insights", isGranted: manager.notificationsAuthorized)
                PermissionRow("Weekly sleep reports", isGranted: manager.notificationsAuthorized)
                PermissionRow("Sleep goal adjustments", isGranted: manager.notificationsAuthorized)
            }
            .onboardingCard()
            
            if manager.notificationsAuthorized {
                Label("Notifications Enabled", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding()
    }
    
    private var watchPairingContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "applewatch.watchface")
                .font(.system(size: 80))
                .symbolEffect(.bounce)
                .accessibilityHidden(true)
            
            Text("Apple Watch Features:")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                PermissionRow("Enhanced sleep tracking")
                PermissionRow("Heart rate monitoring")
                PermissionRow("Movement detection")
                PermissionRow("Silent haptic alarms")
            }
            .onboardingCard()
            
            Button("Open Watch App") {
                openWatchApp()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private var sleepGoalContent: some View {
        VStack(spacing: 24) {
            Text("How much sleep do you need?")
                .font(.headline)
            
            VStack {
                let hours = Int(manager.targetSleepDuration)
                let minutes = Int((manager.targetSleepDuration.truncatingRemainder(dividingBy: 1) * 60))
                Text("\(hours) hours \(minutes) minutes")
                    .font(.system(size: 44, weight: .medium))
                    .accessibilityLabel("Target sleep duration: \(hours) hours and \(minutes) minutes")
                
                Slider(value: $manager.targetSleepDuration, in: 6...10, step: 0.5)
                    .tint(manager.targetSleepDuration >= 7 && manager.targetSleepDuration <= 9 ? .green : .blue)
            }
            .onboardingCard()
            
            Text("When do you want to wake up?")
                .font(.headline)
                .padding(.top)
            
            AdaptiveDatePicker(titleKey: "Target wake time", selection: $manager.targetWakeTime)
                .onboardingCard()
            
            Text("Your bedtime will adjust automatically")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    private var completionContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 100))
                .foregroundColor(.green)
                .symbolEffect(.bounce)
                .accessibilityHidden(true)
            
            Text("You're all set!")
                .font(.title)
                .bold()
            
            Text("Start tracking better sleep tonight")
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                if manager.healthKitAuthorized {
                    Label("Health Integration Ready", systemImage: "heart.fill")
                        .foregroundColor(.green)
                }
                
                if manager.notificationsAuthorized {
                    Label("Notifications Configured", systemImage: "bell.fill")
                        .foregroundColor(.green)
                }
            }
            .onboardingCard()
        }
        .padding()
    }
}

#if DEBUG
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
}
#endif
