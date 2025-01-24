import SwiftUI
import CoreData

struct QuizResultView: View {
    let quiz: Quiz
    let selectedAnswers: [QuizQuestion: QuizAnswer]
    let progress: QuizProgress?
    let onDismiss: () -> Void
    
    private var score: Int16 {
        progress?.score ?? 0
    }
    
    private var hasPassed: Bool {
        score >= quiz.passingScore
    }
    
    private var questions: [QuizQuestion] {
        (quiz.questions?.allObjects as? [QuizQuestion])?
            .sorted { $0.sortOrder < $1.sortOrder } ?? []
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                scoreSection
                answersBreakdown
                actionButtons
            }
            .padding()
        }
    }
    
    private var scoreSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 20)
                    .frame(width: 160, height: 160)
                
                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100)
                    .stroke(hasPassed ? Color.green : Color.orange, lineWidth: 20)
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                
                VStack {
                    Text("\(score)%")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Score")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(hasPassed ? "Congratulations!" : "Keep Learning!")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(hasPassed ? 
                "You've passed the quiz and demonstrated your understanding." :
                "Review the material and try again to improve your score."
            )
            .font(.subheadline)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        }
    }
    
    private var answersBreakdown: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Answer Review")
                .font(.headline)
            
            ForEach(questions) { question in
                answerReviewCard(for: question)
            }
        }
    }
    
    private func answerReviewCard(for question: QuizQuestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(question.question ?? "")
                .font(.subheadline)
                .fontWeight(.medium)
            
            if let selectedAnswer = selectedAnswers[question] {
                HStack {
                    Image(systemName: selectedAnswer.isCorrect ?
                        "checkmark.circle.fill" : "xmark.circle.fill"
                    )
                    .foregroundColor(selectedAnswer.isCorrect ?
                        .green : .red
                    )
                    
                    Text(selectedAnswer.text ?? "")
                        .font(.subheadline)
                }
            }
            
            if let explanation = question.explanation,
               let selectedAnswer = selectedAnswers[question],
               !selectedAnswer.isCorrect {
                Text(explanation)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: onDismiss) {
                Text("Finish")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            
            if !hasPassed {
                Button(action: onDismiss) {
                    Text("Review Material")
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                }
            }
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let quiz = Quiz(context: context)
    quiz.title = "Sample Quiz"
    quiz.passingScore = 70
    return QuizResultView(
        quiz: quiz,
        selectedAnswers: [:],
        progress: nil,
        onDismiss: {}
    )
    .padding()
}