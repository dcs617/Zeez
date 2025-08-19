import SwiftUI
import CoreData
import os.log

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
                    .accessibilityLabel(hasPassed ? "Quiz passed" : "Quiz not passed")
                
                Text(quiz.title ?? "Quiz")
                    .font(.headline)
                
                Spacer()
                
                if hasAttempted {
                    Text("\(bestScore)%")
                        .font(.subheadline)
                        .foregroundColor(hasPassed ? .green : .orange)
                        .accessibilityLabel("Best score: \(bestScore) percent")
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Quiz \(quiz.title ?? "Unknown")\(hasAttempted ? ", best score \(bestScore) percent, \(hasPassed ? "passed" : "not passed")" : ", not attempted")")
            .accessibilityIdentifier("quizStatusHeader")
            
            if hasAttempted {
                Text(hasPassed ? "Completed" : "Try Again")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityLabel(hasPassed ? "Quiz completed successfully" : "Quiz not passed, try again")
            } else {
                Text("Test your knowledge")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityLabel("Quiz not started, test your knowledge")
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
            .accessibilityLabel(hasAttempted ? "Retake quiz" : "Start quiz")
            .accessibilityHint(hasAttempted ? "Take this quiz again to improve your score" : "Begin taking this quiz")
            .accessibilityIdentifier("quizActionButton")
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
                    .accessibilityLabel("Quiz")
                Text(quiz.title ?? "")
                    .font(.headline)
                Spacer()
                Text("\(quiz.questions?.count ?? 0) Questions")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityLabel("\(quiz.questions?.count ?? 0) questions")
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Quiz: \(quiz.title ?? "Unknown"), \(quiz.questions?.count ?? 0) questions")
            .accessibilityIdentifier("quizPreviewHeader")
            
            Text(quiz.quizDescription ?? "")
            .font(.subheadline)
            .foregroundColor(.secondary)
            .lineLimit(2)

            HStack {
                    Text("Pass: \(quiz.passingScore)%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .accessibilityLabel("Passing score: \(quiz.passingScore) percent")
                }
                
                Spacer()
                
                Button(action: {}) {
                    Text("Start Quiz")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                .accessibilityLabel("Start quiz")
                .accessibilityHint("Begin taking this quiz")
                .accessibilityIdentifier("startQuizButton")
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
