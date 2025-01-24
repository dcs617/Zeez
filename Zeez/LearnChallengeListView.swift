import SwiftUI
import CoreData

struct LearnChallengeListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest<LearnChallenge>(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \LearnChallenge.isActive, ascending: false),
            NSSortDescriptor(keyPath: \LearnChallenge.startDate, ascending: true)
        ]
    ) private var challenges
    
    @State private var showingCompletedChallenges = false
    @State private var isAnimating = false
    @State private var selectedChallenge: LearnChallenge?
    @State private var showingChallengeCompletion = false
    
    private var challengeArray: [LearnChallenge] {
        Array(challenges)
    }
    
    private var availableChallenges: [LearnChallenge] {
        challengeArray.filter { !$0.isActive }
    }
    
    private var completedChallenges: [LearnChallenge] {
        challengeArray.filter {
            guard let progress = $0.userProgress else { return false }
            return progress.isCompleted
        }
    }
    
    private var activeChallenge: LearnChallenge? {
        challengeArray.first { $0.isActive }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let activeChallenge {
                    activeChallengeSection(activeChallenge)
                        .transition(.slideAndFade())
                }
                
                availableChallengesSection
                    .fadeInTransition(active: !isAnimating)
                
                if showingCompletedChallenges {
                    completedChallengesSection
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding()
        }
        .navigationTitle("Challenges")
        .toolbar {
            if !completedChallenges.isEmpty {
                Button(action: { 
                    withAnimation {
                        showingCompletedChallenges.toggle()
                    }
                }) {
                    Image(systemName: showingCompletedChallenges ? "chevron.up.circle" : "chevron.down.circle")
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                isAnimating = true
            }
        }
        .onDisappear {
            isAnimating = false
        }
        .overlay {
            if showingChallengeCompletion {
                ChallengeCompletionAnimation(isShowing: $showingChallengeCompletion) {
                    selectedChallenge = nil
                }
            }
        }
    }
    
    private func activeChallengeSection(_ challenge: LearnChallenge) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Active Challenge")
                    .font(.headline)
                
                Spacer()
                
                LearnProgressAnimation(
                    progress: challenge.userProgress?.progress ?? 0,
                    color: .blue
                )
                .frame(width: 24, height: 24)
            }
            
            ChallengeCard(challenge: challenge)
        }
        .fadeInTransition(active: !isAnimating)
    }
    
    private var availableChallengesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Available Challenges")
                .font(.headline)
            
            ForEach(Array(availableChallenges.enumerated()), id: \.1.id) { index, challenge in
                ChallengeCard(challenge: challenge)
                    .fadeInTransition(active: !isAnimating)
                    .transition(.scale.combined(with: .opacity))
                    .animation(.easeInOut.delay(Double(index) * 0.1), value: isAnimating)
            }
        }
    }
    
    private var completedChallengesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Completed")
                    .font(.headline)
                
                Spacer()
                
                Button("Hide") {
                    withAnimation {
                        showingCompletedChallenges = false
                    }
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            ForEach(completedChallenges) { challenge in
                CompletedChallengeRow(challenge: challenge)
                    .cardFlip(isFlipped: !isAnimating)
            }
        }
    }
}

struct ChallengeCard: View {
    let challenge: LearnChallenge
    @State private var showingDetail = false
    @State private var isHovered = false
    
    var body: some View {
        Button(action: { showingDetail = true }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(challenge.title ?? "Untitled Challenge")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text("\(challenge.points) pts")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                }
                
                Text(challenge.challengeDescription ?? "No description available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack {
                    Text("\(challenge.durationDays) days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let progress = challenge.userProgress {
                        Spacer()
                        
                        ProgressView(value: progress.progress)
                            .frame(width: 100)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.spring(), value: isHovered)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetail) {
            LearnChallengeDetailView(challengeId: challenge.objectID)
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct CompletedChallengeRow: View {
    let challenge: LearnChallenge
    @State private var isHovered = false
    
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .scaleEffect(isHovered ? 1.1 : 1.0)
            
            VStack(alignment: .leading) {
                Text(challenge.title ?? "Untitled Challenge")
                    .font(.subheadline)
                
                if let earnedDate = challenge.userProgress?.earnedDate {
                    Text("Completed \(earnedDate, style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text("\(challenge.points) pts")
                .font(.caption)
                .foregroundColor(.orange)
        }
        .padding(.vertical, 8)
        .onHover { hovering in
            withAnimation(.spring()) {
                isHovered = hovering
            }
        }
    }
}

extension AnyTransition {
    static func slideAndFade() -> AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .scale.combined(with: .opacity)
        )
    }
}

#Preview {
    LearnChallengeListView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}