import SwiftUI
import os.log

// MARK: - Platform Environment
enum PlatformEnvironment {
    #if os(iOS)
    static let background = Color(uiColor: .systemBackground)
    static let secondaryBackground = Color(uiColor: .secondarySystemBackground)
    #else
    static let background = Color(.windowBackgroundColor)
    static let secondaryBackground = Color(.controlBackgroundColor)
    #endif
}

// MARK: - View Modifiers
struct OnboardingCardModifier: ViewModifier {
    let useBlur: Bool
    
    init(useBlur: Bool = true) {
        self.useBlur = useBlur
    }
    
    func body(content: Content) -> some View {
        content
            .padding()
            #if os(iOS)
            .background {
                if useBlur {
                    Rectangle()
                        .fill(.regularMaterial)
                } else {
                    Rectangle()
                        .fill(PlatformEnvironment.secondaryBackground)
                }
            }
            #else
            .background(Color.gray.opacity(0.1))
            #endif
            .cornerRadius(16)
            .shadow(radius: 2, y: 2)
    }
}

// MARK: - Adaptive Components
#if os(iOS)
struct AdaptiveDatePicker: View {
    let titleKey: LocalizedStringKey
    @Binding var selection: Date
    
    var body: some View {
        DatePicker(titleKey, selection: $selection, displayedComponents: .hourAndMinute)
            .datePickerStyle(.wheel)
            .labelsHidden()
    }
}
#else
struct AdaptiveDatePicker: View {
    let titleKey: LocalizedStringKey
    @Binding var selection: Date
    
    var body: some View {
        DatePicker(titleKey, selection: $selection, displayedComponents: .hourAndMinute)
            .datePickerStyle(.stepperField)
            .labelsHidden()
    }
}
#endif

// MARK: - Reusable Components
struct PermissionRow: View {
    let text: String
    let isGranted: Bool
    
    init(_ text: String, isGranted: Bool = false) {
        self.text = text
        self.isGranted = isGranted
    }
    
    var body: some View {
        HStack {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isGranted ? .green : .secondary)
            Text(text)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(text) \(isGranted ? "granted" : "not granted")")
    }
}

struct OnboardingButton: View {
    let title: String
    let action: () -> Void
    let isLoading: Bool
    
    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Text(title)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .disabled(isLoading)
        .animation(.easeInOut(duration: 0.3), value: isLoading)
    }
}

struct OnboardingProgressView: View {
    let currentStep: OnboardingStep
    
    private var progress: CGFloat {
        guard let index = OnboardingStep.allCases.firstIndex(of: currentStep) else { return 0 }
        return CGFloat(index) / CGFloat(OnboardingStep.allCases.count - 1)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(.accentColor)
            
            HStack {
                Text("Step \((OnboardingStep.allCases.firstIndex(of: currentStep) ?? 0) + 1) of \(OnboardingStep.allCases.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .animation(.easeInOut(duration: 0.5), value: progress)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Progress: Step \((OnboardingStep.allCases.firstIndex(of: currentStep) ?? 0) + 1) of \(OnboardingStep.allCases.count), \(Int(progress * 100))% complete")
    }
}

// MARK: - View Extensions
extension View {
    func onboardingCard(useBlur: Bool = true) -> some View {
        modifier(OnboardingCardModifier(useBlur: useBlur))
    }
    
    func adaptiveBackground() -> some View {
        #if os(iOS)
        self.background(PlatformEnvironment.background)
        #else
        self.background(PlatformEnvironment.background)
        #endif
    }
    
    func adaptiveNavigationBar() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}

// MARK: - Haptic Feedback
func triggerHapticFeedback() {
    #if os(iOS)
    let generator = UIImpactFeedbackGenerator(style: .medium)
    generator.prepare()
    generator.impactOccurred()
    #endif
}

func triggerSelectionFeedback() {
    #if os(iOS)
    let generator = UISelectionFeedbackGenerator()
    generator.selectionChanged()
    #endif
}

func triggerErrorFeedback() {
    #if os(iOS)
    let generator = UINotificationFeedbackGenerator()
    generator.notificationOccurred(.error)
    #endif
}

// MARK: - Platform Utilities
func openWatchApp() {
    #if os(iOS)
    if let url = URL(string: "x-apple-watch://") {
        UIApplication.shared.open(url)
    }
    #endif
}
