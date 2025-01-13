import SwiftUI

struct OnboardingView: View {
    @StateObject private var onboardingManager = OnboardingManager.shared
    @State private var targetSleepDuration: Double = 8.0
    @State private var targetBedtime = Date()
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack {
                headerSection
                
                Spacer()
                
                mainContent
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .padding()
                } else {
                    navigationButtons
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: onboardingManager.currentStep.systemImage)
                .font(.system(size: 60))
                .foregroundColor(.purple)
            
            Text(onboardingManager.currentStep.title)
                .font(.title)
                .bold()
            
            Text(onboardingManager.currentStep.description)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding(.top)
    }
    
    @ViewBuilder
    private var mainContent: some View {
        switch onboardingManager.currentStep {
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
    
    private var welcomeContent: some View {
        VStack(spacing: 24) {
            FeatureCard(
                icon: "moon.stars",
                title: "Track Sleep",
                description: "Monitor your sleep patterns and quality"
            )
            
            FeatureCard(
                icon: "chart.bar",
                title: "Get Insights",
                description: "Understand your sleep habits better"
            )
            
            FeatureCard(
                icon: "bell",
                title: "Smart Alarms",
                description: "Wake up at the optimal time"
            )
        }
    }
    
    private var healthKitContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 80))
                .foregroundColor(.red)
            
            Text("Zeez uses HealthKit to:")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                PermissionRow(text: "Track sleep duration and quality")
                PermissionRow(text: "Monitor heart rate during sleep")
                PermissionRow(text: "Calculate sleep metrics and trends")
            }
            
            if onboardingManager.healthKitAuthorized {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title)
            }
        }
    }
    
    private var notificationsContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.badge")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("Get notified about:")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                PermissionRow(text: "Bedtime reminders")
                PermissionRow(text: "Sleep insights and recommendations")
                PermissionRow(text: "Smart alarm wake-up times")
            }
            
            if onboardingManager.notificationsAuthorized {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title)
            }
        }
    }
    
    private var watchPairingContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "applewatch.watchface")
                .font(.system(size: 80))
            
            Text("Enhanced tracking with Apple Watch:")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                PermissionRow(text: "Precise sleep tracking")
                PermissionRow(text: "Heart rate monitoring")
                PermissionRow(text: "Silent, haptic alarms")
            }
            
            Button("Open Watch App") {
                if let url = URL(string: "x-apple-watch://") {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
        }
    }
    
    private var sleepGoalContent: some View {
        VStack(spacing: 24) {
            Text("How much sleep do you need?")
                .font(.headline)
            
            Slider(value: $targetSleepDuration, in: 6...10, step: 0.5)
                .padding(.horizontal)
            
            Text("\(targetSleepDuration, specifier: "%.1f") hours")
                .font(.title2)
            
            Text("When do you want to wake up?")
                .font(.headline)
                .padding(.top)
            
            DatePicker("Target wake time", selection: $targetBedtime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
        }
    }
    
    private var completionContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 100))
                .foregroundColor(.green)
            
            Text("You're all set!")
                .font(.title)
            
            Text("Start tracking better sleep tonight")
                .foregroundColor(.secondary)
        }
    }
    
    private var navigationButtons: some View {
        HStack {
            if onboardingManager.currentStep != .welcome {
                Button("Back") {
                    withAnimation {
                        moveToStep(.backward)
                    }
                }
            }
            
            Spacer()
            
            Button(onboardingManager.currentStep == .completion ? "Get Started" : "Continue") {
                withAnimation {
                    handleContinue()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.bottom)
    }
    
    private func handleContinue() {
        Task {
            isLoading = true
            defer { isLoading = false }
            
            switch onboardingManager.currentStep {
            case .healthKit:
                if await onboardingManager.requestHealthKitPermissions() {
                    moveToStep(.forward)
                }
            case .notifications:
                if await onboardingManager.requestNotificationPermissions() {
                    moveToStep(.forward)
                }
            case .completion:
                saveSleepPreferences()
                onboardingManager.completeOnboarding()
            default:
                moveToStep(.forward)
            }
        }
    }
    
    private func moveToStep(_ direction: StepDirection) {
        let allSteps = OnboardingStep.allCases
        guard let currentIndex = allSteps.firstIndex(of: onboardingManager.currentStep) else {
            return
        }
        
        switch direction {
        case .forward:
            guard currentIndex < allSteps.count - 1 else { return }
            onboardingManager.currentStep = allSteps[currentIndex + 1]
        case .backward:
            guard currentIndex > 0 else { return }
            onboardingManager.currentStep = allSteps[currentIndex - 1]
        }
    }
    
    private func saveSleepPreferences() {
        let context = PersistenceController.shared.container.viewContext
        let preferences = UserPreferences(context: context)
        
        preferences.id = UUID()
        preferences.targetSleepDuration = targetSleepDuration * 3600
        preferences.targetWakeTime = targetBedtime
        preferences.targetBedtime = Calendar.current.date(
            byAdding: .hour,
            value: -Int(targetSleepDuration),
            to: targetBedtime
        )
        preferences.sleepGoalEnabled = true
        preferences.createdAt = Date()
        preferences.modifiedAt = Date()
        
        try? context.save()
    }
    
    private enum StepDirection {
        case forward
        case backward
    }
}

struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(.purple)
                .frame(width: 44)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct PermissionRow: View {
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(text)
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
}