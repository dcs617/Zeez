import SwiftUI
import WatchConnectivity
import os.log

struct OnboardingView: View {
    @StateObject private var manager = OnboardingManager.shared

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    private var computedBedtime: Date {
        OnboardingManager.computeBedtime(wakeTime: manager.targetWakeTime, sleepHours: manager.targetSleepHours)
    }

    private var sleepGoalSummary: String {
        let hours = Int(manager.targetSleepHours)
        let minutes = Int(manager.targetSleepHours.truncatingRemainder(dividingBy: 1) * 60)
        return minutes == 0 ? "\(hours) hours of sleep" : "\(hours) hrs \(minutes) min of sleep"
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                OnboardingProgressView(currentStep: manager.currentStep)
                    .padding(.top)

                ScrollView {
                    VStack {
                        switch manager.currentStep {
                        case .welcome:       welcomeContent
                        case .healthKit:     healthKitContent
                        case .notifications: notificationsContent
                        case .watchPairing:  watchPairingContent
                        case .sleepGoal:     sleepGoalContent
                        case .completion:    completionContent
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
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if manager.canGoBack {
                        Button(action: { manager.moveToPreviousStep() }) {
                            Image(systemName: "chevron.left")
                                .fontWeight(.semibold)
                        }
                        .accessibilityLabel("Back")
                    }
                }
            }
            .alert(manager.activeError?.alertTitle ?? "Something Went Wrong", isPresented: $manager.showErrorAlert) {
                Button("OK", role: .cancel) {}
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

    // MARK: - Step Content

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
                PermissionRow("Review imported sleep records and reported stages")
                PermissionRow("Review available heart rate records")
                PermissionRow("Compare recordings with your selected sleep goal")
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

            Text("Health Integration")
                .font(.headline)

            if manager.healthKitAvailable {
                Text("Zeez reads sleep, heart rate, and respiratory data from Apple Health for your review. It never writes data back.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 12) {
                    PermissionRow("Import sleep records from Apple Health")
                    PermissionRow("Enrich sessions with heart rate data")
                    PermissionRow("Track respiratory rate during sleep")
                }
                .onboardingCard()

                if manager.healthKitSetupCompleted {
                    Label("Apple Health setup complete", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            } else {
                Text("Apple Health isn't available on this device. Apple Health sleep import cannot be used here.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .onboardingCard()
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

            Text("Stay Updated")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                PermissionRow("Alarm and reminder notifications", isGranted: manager.notificationsAuthorized)
                PermissionRow("Alarm follow-up alerts when configured", isGranted: manager.notificationsAuthorized)
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

            Text("Apple Watch (Optional)")
                .font(.headline)

            Text("Pairing your watch lets you review the latest synced session and use supported alarm controls. You can skip this step.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 12) {
                PermissionRow("Latest recorded session summary")
                PermissionRow("Experimental Zeez estimate shown only when available")
                PermissionRow("Silent haptic alarms")
            }
            .onboardingCard()

            #if os(iOS)
            if WCSession.isSupported() {
                Button("Open Watch App") { openWatchApp() }
                    .buttonStyle(.bordered)
            }
            #endif
        }
        .padding()
    }

    private var sleepGoalContent: some View {
        VStack(spacing: 24) {
            Text("What sleep goal would you like to set?")
                .font(.headline)

            VStack {
                let hours = Int(manager.targetSleepHours)
                let minutes = Int(manager.targetSleepHours.truncatingRemainder(dividingBy: 1) * 60)
                Text("\(hours) hours \(minutes) minutes")
                    .font(.system(size: 44, weight: .medium))
                    .accessibilityLabel("Target sleep duration: \(hours) hours and \(minutes) minutes")

                Slider(value: $manager.targetSleepHours, in: 6...10, step: 0.5)
                    .tint(manager.targetSleepHours >= 7 && manager.targetSleepHours <= 9 ? .green : .blue)
            }
            .onboardingCard()

            Text("When do you want to wake up?")
                .font(.headline)
                .padding(.top)

            AdaptiveDatePicker(titleKey: "Target wake time", selection: $manager.targetWakeTime)
                .onboardingCard()

            HStack(spacing: 6) {
                Image(systemName: "bed.double.fill")
                Text("Bedtime: \(Self.timeFormatter.string(from: computedBedtime))")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            .accessibilityLabel("Planned bedtime: \(Self.timeFormatter.string(from: computedBedtime))")
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

            Text("Here's your selected sleep goal")
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                Label(sleepGoalSummary, systemImage: "moon.zzz.fill")
                Label("Wake at \(Self.timeFormatter.string(from: manager.targetWakeTime))", systemImage: "alarm.fill")
                Label("Bedtime \(Self.timeFormatter.string(from: computedBedtime))", systemImage: "bed.double.fill")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .onboardingCard()

            if manager.healthKitSetupCompleted || manager.notificationsAuthorized {
                VStack(spacing: 8) {
                    if manager.healthKitSetupCompleted {
                        Label("Apple Health setup complete", systemImage: "heart.fill")
                            .foregroundColor(.green)
                    }
                    if manager.notificationsAuthorized {
                        Label("Notifications Configured", systemImage: "bell.fill")
                            .foregroundColor(.green)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .onboardingCard()
            }
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
