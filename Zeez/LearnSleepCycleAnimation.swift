import SwiftUI

struct LearnSleepCycleAnimation: View {
    @State private var cycleProgress: Double = 0
    @State private var isAnimating = false
    @State private var currentStage: SleepStage = .awake
    @State private var showingStageInfo = false
    
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    enum SleepStage: Int, CaseIterable {
        case awake = 0
        case light = 1
        case deep = 2
        case rem = 3
        
        var color: Color {
            switch self {
            case .awake: return .yellow
            case .light: return .blue
            case .deep: return .indigo
            case .rem: return .purple
            }
        }
        
        var name: String {
            switch self {
            case .awake: return "Awake"
            case .light: return "Light Sleep"
            case .deep: return "Deep Sleep"
            case .rem: return "REM"
            }
        }
        
        var description: String {
            switch self {
            case .awake:
                return "Transitional period before falling asleep"
            case .light:
                return "Initial stage of sleep, easier to wake up"
            case .deep:
                return "Most restorative sleep stage, body repairs and regenerates"
            case .rem:
                return "Dream stage, important for memory and learning"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                    .frame(width: 200, height: 200)
                
                // Progress circle
                Circle()
                    .trim(from: 0, to: cycleProgress)
                    .stroke(currentStage.color, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.05), value: cycleProgress)
                
                // Stage indicator
                VStack {
                    Text(currentStage.name)
                        .font(.headline)
                    Text("\(Int(cycleProgress * 100))%")
                        .font(.subheadline)
                }
                .onTapGesture {
                    showingStageInfo.toggle()
                }
            }
            
            HStack(spacing: 20) {
                Button(action: { toggleAnimation() }) {
                    Label(isAnimating ? "Pause" : "Play", systemImage: isAnimating ? "pause.fill" : "play.fill")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Button(action: { resetAnimation() }) {
                    Label("Reset", systemImage: "arrow.clockwise")
                        .padding()
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
        .onReceive(timer) { _ in
            if isAnimating {
                updateProgress()
            }
        }
        .sheet(isPresented: $showingStageInfo) {
            SleepCycleStageInfoView(stage: currentStage)
        }
    }
    
    private func updateProgress() {
        cycleProgress += 0.001
        if cycleProgress >= 1 {
            cycleProgress = 0
        }
        updateCurrentStage()
    }
    
    private func updateCurrentStage() {
        let stageProgress = cycleProgress * 4
        currentStage = SleepStage(rawValue: Int(stageProgress)) ?? .awake
    }
    
    private func toggleAnimation() {
        isAnimating.toggle()
    }
    
    private func resetAnimation() {
        cycleProgress = 0
        currentStage = .awake
        isAnimating = false
    }
}

struct SleepCycleStageInfoView: View {
    let stage: LearnSleepCycleAnimation.SleepStage
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Circle()
                        .fill(stage.color)
                        .frame(width: 20, height: 20)
                    Text(stage.name)
                        .font(.title)
                }
                
                Text(stage.description)
                    .font(.body)
                
                Spacer()
            }
            .padding()
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
    }
}

#Preview {
    LearnSleepCycleAnimation()
}
