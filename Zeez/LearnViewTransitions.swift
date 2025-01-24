import SwiftUI

struct SlideTransition: ViewModifier {
    let edge: Edge
    let active: Bool
    
    func body(content: Content) -> some View {
        content
            .offset(x: active ? (edge == .leading ? -30 : 30) : 0)
            .opacity(active ? 0 : 1)
            .animation(.easeInOut(duration: 0.3), value: active)
    }
}

struct FadeInTransition: ViewModifier {
    let active: Bool
    
    func body(content: Content) -> some View {
        content
            .opacity(active ? 0 : 1)
            .scaleEffect(active ? 0.95 : 1)
            .animation(.easeOut(duration: 0.3), value: active)
    }
}

struct CardFlipTransition: ViewModifier {
    let isFlipped: Bool
    
    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(isFlipped ? 180 : 0),
                axis: (x: 0.0, y: 1.0, z: 0.0)
            )
            .animation(.easeInOut(duration: 0.5), value: isFlipped)
    }
}

extension View {
    func slideTransition(from edge: Edge = .trailing, active: Bool = false) -> some View {
        modifier(SlideTransition(edge: edge, active: active))
    }
    
    func fadeInTransition(active: Bool = false) -> some View {
        modifier(FadeInTransition(active: active))
    }
    
    func cardFlip(isFlipped: Bool = false) -> some View {
        modifier(CardFlipTransition(isFlipped: isFlipped))
    }
}

struct LearnProgressAnimation: View {
    let progress: Double
    let color: Color
    @State private var animatedProgress: Double = 0
    
    var body: some View {
        Circle()
            .trim(from: 0, to: animatedProgress)
            .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .onAppear {
                withAnimation(.easeOut(duration: 1.0)) {
                    animatedProgress = progress
                }
            }
            .onChange(of: progress) { newValue in
                withAnimation(.easeOut(duration: 1.0)) {
                    animatedProgress = newValue
                }
            }
    }
}

struct ChallengeCompletionAnimation: View {
    @Binding var isShowing: Bool
    let onComplete: () -> Void
    
    var body: some View {
        VStack {
            if isShowing {
                VStack(spacing: 20) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.yellow)
                        .transition(.scale.combined(with: .opacity))
                    
                    Text("Challenge Complete!")
                        .font(.title2.bold())
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            isShowing = false
                            onComplete()
                        }
                    }
                }
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: isShowing)
    }
}

struct BadgeUnlockAnimation: View {
    let badgeImage: String
    let title: String
    @Binding var isShowing: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            if isShowing {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .overlay(
                        Image(systemName: badgeImage)
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                    )
                    .transition(.scale.combined(with: .opacity))
                
                Text("New Badge Unlocked!")
                    .font(.headline)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: isShowing)
        .onChange(of: isShowing) { newValue in
            if newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        isShowing = false
                    }
                }
            }
        }
    }
}