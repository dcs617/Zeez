import SwiftUI
import CoreData

struct LearnQuizStatusView: View {
    let quiz: Quiz
    @FetchRequest private var progress: FetchedResults<QuizProgress>
    
    init(quiz: Quiz) {
        self.quiz = quiz
        _progress = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \QuizProgress.completedAt, ascending: false)],
            predicate: NSPredicate(format: "quiz == %@", quiz)
        )
    }
    
    private var bestScore: Int16 {
        progress.map(\.score).max() ?? 0
    }
    
    private var hasAttempted: Bool {
        !progress.isEmpty
    }
    
    private var hasPassed: Bool {
        bestScore >= (quiz.passingScore)
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: hasPassed ? "checkmark.seal.fill" : "seal.fill")
                    .foregroundColor(hasPassed ? .green : .orange)
                
                Text(quiz.title ?? "Quiz")
                    .font(.headline)
                
                Spacer()
                
                if hasAttempted {
                    Text("\(bestScore)%")
                        .font(.subheadline)
                        .foregroundColor(hasPassed ? .green : .orange)
                }
            }
            
            if hasAttempted {
                Text(hasPassed ? "Completed" : "Try Again")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Test your knowledge")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Button(action: {}) {
                Text(hasAttempted ? "Retake Quiz" : "Start Quiz")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct LearnQuizPreviewCard: View {
    let quiz: Quiz
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "graduationcap.fill")
                    .foregroundColor(.blue)
                Text(quiz.title ?? "")
                    .font(.headline)
                Spacer()
                Text("\(quiz.questions?.count ?? 0) Questions")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(quiz.quizDescription ?? "")
            .font(.subheadline)
            .foregroundColor(.secondary)
            .lineLimit(2)

            HStack {
                    Text("Pass: \(quiz.passingScore)%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {}) {
                    Text("Start Quiz")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let quiz = Quiz(context: context)
    quiz.title = "Sleep Basics"
    quiz.passingScore = 70
    return VStack {
        LearnQuizStatusView(quiz: quiz)
        LearnQuizPreviewCard(quiz: quiz)
    }
    .padding()
    .environment(\.managedObjectContext, context)
}
