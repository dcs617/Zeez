import SwiftUI
import os.log

struct LearnOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasCompletedLearnOnboarding") private var hasCompletedOnboarding = false
    @State private var selectedPage = 0
    @GestureState private var dragOffset: CGFloat = 0
    
    private let pages = [
        OnboardingPage(
            title: "Learn About Sleep",
            description: "Discover the science of sleep and how to improve your rest through evidence-based articles and guides.",
            imageName: "book.fill",
            color: .blue
        ),
        OnboardingPage(
            title: "Track Your Progress",
            description: "Complete challenges and earn achievements as you build better sleep habits.",
            imageName: "trophy.fill",
            color: .orange
        ),
        OnboardingPage(
            title: "Stay Motivated",
            description: "Set learning goals, maintain streaks, and see your progress over time.",
            imageName: "chart.line.uptrend.xyaxis",
            color: .green
        ),
        OnboardingPage(
            title: "Get Reminded",
            description: "Set up notifications to help you maintain your learning streak and complete challenges.",
            imageName: "bell.fill",
            color: .purple
        )
    ]
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button("Skip") {
                    completeOnboarding()
                }
                .padding()
                .accessibilityLabel("Skip onboarding")
                .accessibilityHint("Skip the onboarding tour and go to Learn section")
                .accessibilityIdentifier("skipOnboardingButton")
            }
            
            TabView(selection: $selectedPage) {
                ForEach(pages.indices, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .accessibilityLabel("Onboarding pages")
            .accessibilityHint("Swipe left or right to navigate between onboarding pages")
            .accessibilityIdentifier("onboardingTabView")
            
            HStack(spacing: 20) {
                if selectedPage > 0 {
                    Button(action: { withAnimation { selectedPage -= 1 } }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Previous")
                        }
                        .foregroundColor(.blue)
                    }
                    .accessibilityLabel("Previous page")
                    .accessibilityHint("Go to the previous onboarding page")
                    .accessibilityIdentifier("previousPageButton")
                }
                
                if selectedPage < pages.count - 1 {
                    Button(action: { withAnimation { selectedPage += 1 } }) {
                        HStack {
                            Text("Next")
                            Image(systemName: "chevron.right")
                        }
                        .foregroundColor(.blue)
                    }
                    .accessibilityLabel("Next page")
                    .accessibilityHint("Go to the next onboarding page")
                    .accessibilityIdentifier("nextPageButton")
                } else {
                    Button(action: completeOnboarding) {
                        Text("Get Started")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .accessibilityLabel("Get started")
                    .accessibilityHint("Complete onboarding and enter the Learn section")
                    .accessibilityIdentifier("getStartedButton")
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(Color(.systemBackground))
        .gesture(
            DragGesture()
                .updating($dragOffset) { value, state, _ in
                    state = value.translation.width
                }
                .onEnded { value in
                    let threshold: CGFloat = 50
                    if value.translation.width > threshold && selectedPage > 0 {
                        withAnimation {
                            selectedPage -= 1
                        }
                    } else if value.translation.width < -threshold && selectedPage < pages.count - 1 {
                        withAnimation {
                            selectedPage += 1
                        }
                    }
                }
        )
        .interactiveDismissDisabled()
    }
    
    private func completeOnboarding() {
        hasCompletedOnboarding = true
        dismiss()
    }
}

struct OnboardingPage {
    let title: String
    let description: String
    let imageName: String
    let color: Color
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: page.imageName)
                .font(.system(size: 80))
                .foregroundColor(page.color)
                .scaleEffect(isAnimating ? 1 : 0.5)
                .opacity(isAnimating ? 1 : 0)
                .accessibilityLabel("\(page.title) illustration")
                .accessibilityIdentifier("onboardingPageIcon")
            
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .opacity(isAnimating ? 1 : 0)
                    .offset(y: isAnimating ? 0 : 20)
                    .accessibilityLabel(page.title)
                    .accessibilityIdentifier("onboardingPageTitle")
                
                Text(page.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .opacity(isAnimating ? 1 : 0)
                    .offset(y: isAnimating ? 0 : 20)
                    .accessibilityLabel(page.description)
                    .accessibilityIdentifier("onboardingPageDescription")
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(page.title). \(page.description)")
            
            Spacer()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                isAnimating = true
            }
        }
        .onDisappear {
            isAnimating = false
        }
    }
}

struct LearnWelcomeSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Binding var isPresented: Bool
    @State private var showingNotificationRequest = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                welcomeImage
                welcomeContent
                actionButtons
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        isPresented = false
                    }
                    .accessibilityLabel("Skip welcome")
                    .accessibilityHint("Skip the welcome screen and continue")
                    .accessibilityIdentifier("skipWelcomeButton")
                }
            }
        }
        .alert("Enable Notifications", isPresented: $showingNotificationRequest) {
            Button("Enable") {
                requestNotifications()
                isPresented = false
            }
            Button("Not Now", role: .cancel) {
                isPresented = false
            }
        } message: {
            Text("Get reminders about new content and streak maintenance.")
        }
    }
    
    private var welcomeImage: some View {
        Image(systemName: "books.vertical.fill")
            .font(.system(size: 60))
            .foregroundColor(.blue)
            .padding()
            .background(Circle().fill(Color.blue.opacity(0.1)))
            .accessibilityLabel("Welcome to Learn illustration")
            .accessibilityIdentifier("welcomeImage")
    }
    
    private var welcomeContent: some View {
        VStack(spacing: 16) {
            Text("Welcome to Learn")
                .font(.title2)
                .fontWeight(.bold)
                .accessibilityLabel("Welcome to Learn")
            
            Text("Discover the science of sleep and build better habits through our curated content and challenges.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .accessibilityLabel("Discover the science of sleep and build better habits through our curated content and challenges")
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("welcomeContent")
    }
    
    private var actionButtons: some View {
        VStack(spacing: 16) {
            Button(action: { showingNotificationRequest = true }) {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .accessibilityLabel("Get started with Learn")
            .accessibilityHint("Begin using the Learn section and enable notifications")
            .accessibilityIdentifier("getStartedWithLearnButton")
            
            NavigationLink(destination: LearnSettingsView()) {
                Text("Customize Settings")
                    .font(.headline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
            }
            .accessibilityLabel("Customize Learn settings")
            .accessibilityHint("Open settings to customize your Learn experience")
            .accessibilityIdentifier("customizeLearnSettingsButton")
        }
    }
    
    private func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            if granted {
                // Schedule initial notifications
                LearnNotificationManager.shared.scheduleLearningReminder(
                    at: Calendar.current.date(from: DateComponents(hour: 20, minute: 0)) ?? Date(),
                    category: .basics
                )
            }
        }
    }
}

#Preview {
    LearnOnboardingView()
}
