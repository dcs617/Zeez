import SwiftUI
import CoreData
import os.log

struct LearnProgressMiniWidget: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var currentStreak = 0
    @State private var overallProgress = 0.0
    
    var body: some View {
        HStack(spacing: 16) {
            // Streak Indicator
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                    Text("\(currentStreak)")
                        .font(.headline)
                }
                Text("Day Streak")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Progress Ring
            VStack(spacing: 4) {
                MiniProgressRing(progress: overallProgress)
                    .frame(width: 32, height: 32)
                Text("Complete")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            updateProgress()
        }
    }
    
    private func updateProgress() {
        let tracker = LearnProgressTracker.shared
        currentStreak = tracker.getCurrentStreak(context: viewContext)
        overallProgress = tracker.calculateOverallProgress(context: viewContext)
    }
}

struct MiniProgressRing: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 3)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.blue, style: StrokeStyle(
                    lineWidth: 3,
                    lineCap: .round
                ))
                .rotationEffect(.degrees(-90))
            
            Text("\(Int(progress * 100))%")
                .font(.system(size: 10))
                .fontWeight(.medium)
        }
    }
}

struct LearnArticleQuizBadge: View {
    let quiz: Quiz?
    @FetchRequest<QuizProgress>(
        sortDescriptors: [NSSortDescriptor(keyPath: \QuizProgress.completedAt, ascending: false)]
    ) private var progress
    
    init(quiz: Quiz?) {
        self.quiz = quiz
        
        let predicate: NSPredicate
        if let quiz = quiz {
            predicate = NSPredicate(format: "quiz == %@", quiz)
        } else {
            predicate = NSPredicate(value: false)
        }
        
        _progress = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \QuizProgress.completedAt, ascending: false)],
            predicate: predicate
        )
    }
    
    private var bestScore: Int16 {
        Array(progress).map(\.score).max() ?? 0
    }
    
    private var hasPassed: Bool {
        bestScore >= (quiz?.passingScore ?? 0)
    }
    
    private var progressArray: [QuizProgress] {
        Array(progress)
    }
    
    var body: some View {
        if quiz != nil {
            HStack(spacing: 4) {
                Image(systemName: "graduationcap.fill")
                    .font(.caption)
                    .foregroundColor(progressArray.isEmpty ? .blue : (hasPassed ? .green : .orange))
                
                if !progressArray.isEmpty {
                    Text("\(bestScore)%")
                        .font(.caption)
                        .foregroundColor(hasPassed ? .green : .orange)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        LearnProgressMiniWidget()
        LearnArticleQuizBadge(quiz: nil)
        LearnAchievementNotification(
            title: "7 Day Streak!",
            message: "You've been learning for a week straight",
            systemImage: "flame.fill",
            color: .orange
        )
    }
    .padding()
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

