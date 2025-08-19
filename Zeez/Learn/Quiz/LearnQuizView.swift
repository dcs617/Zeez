import SwiftUI
import CoreData
import os.log

struct LearnQuizView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let quiz: Quiz
    @State private var currentQuestionIndex = 0
    @State private var selectedAnswers: [QuizQuestion: QuizAnswer] = [:]
    @State private var showingResults = false
    @State private var isQuitting = false
    @State private var progress: QuizProgress?
    
    private var currentQuestion: QuizQuestion? {
        (quiz.questions?.allObjects as? [QuizQuestion])?
            .sorted { $0.sortOrder < $1.sortOrder }[safe: currentQuestionIndex]
    }
    
    private var canProceed: Bool {
        currentQuestion.map { selectedAnswers[$0] != nil } ?? false
    }
    
    var body: some View {
        VStack(spacing: 0) {
            progressHeader
            
            if showingResults {
                QuizResultView(
                    quiz: quiz,
                    selectedAnswers: selectedAnswers,
                    progress: progress,
                    onDismiss: { dismiss() }
                )
            } else if let question = currentQuestion {
                QuizQuestionView(
                    question: question,
                    selectedAnswer: selectedAnswers[question],
                    onAnswerSelected: { answer in
                        selectedAnswers[question] = answer
                    }
                )
            }
            
            if !showingResults {
                navigationFooter
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationTitle(quiz.title ?? "Quiz")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Quit") {
                    isQuitting = true
                }
                .accessibilityLabel("Quit quiz")
                .accessibilityHint("Exit quiz without saving progress")
                .accessibilityIdentifier("quitQuizButton")
            }
        }
        .alert("Quit Quiz?", isPresented: $isQuitting) {
            Button("Quit", role: .destructive) {
                dismiss()
            }
            .accessibilityLabel("Quit quiz")
            .accessibilityHint("Exit quiz without saving progress")
            Button("Continue", role: .cancel) { }
            .accessibilityLabel("Continue quiz")
            .accessibilityHint("Stay in quiz and continue answering questions")
        } message: {
            Text("Your progress will not be saved.")
        }
    }
    
    private var progressHeader: some View {
        VStack(spacing: 4) {
            ProgressView(
                value: Double(currentQuestionIndex),
                total: Double(quiz.questions?.count ?? 0)
            )
            .tint(.blue)
            .accessibilityLabel("Progress: question \(currentQuestionIndex + 1) of \(quiz.questions?.count ?? 0)")
            .accessibilityIdentifier("quizProgress")
            
            HStack {
                Text("Question \(currentQuestionIndex + 1) of \(quiz.questions?.count ?? 0)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Passing Score: \(quiz.passingScore)%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Question \(currentQuestionIndex + 1) of \(quiz.questions?.count ?? 0). Passing score: \(quiz.passingScore) percent")
            .accessibilityIdentifier("quizProgressInfo")
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private var navigationFooter: some View {
        HStack {
            if currentQuestionIndex > 0 {
                Button(action: previousQuestion) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Previous")
                    }
                }
                .accessibilityLabel("Previous question")
                .accessibilityHint("Go back to the previous question")
                .accessibilityIdentifier("previousQuestionButton")
            }
            
            Spacer()
            
            if let question = currentQuestion,
               selectedAnswers[question] != nil {
                Button(action: nextQuestion) {
                    if currentQuestionIndex == (quiz.questions?.count ?? 0) - 1 {
                        Text("Finish")
                            .bold()
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    } else {
                        HStack {
                            Text("Next")
                            Image(systemName: "chevron.right")
                        }
                    }
                }
                .accessibilityLabel(currentQuestionIndex == (quiz.questions?.count ?? 0) - 1 ? "Finish quiz" : "Next question")
                .accessibilityHint(currentQuestionIndex == (quiz.questions?.count ?? 0) - 1 ? "Complete quiz and see results" : "Go to the next question")
                .accessibilityIdentifier(currentQuestionIndex == (quiz.questions?.count ?? 0) - 1 ? "finishQuizButton" : "nextQuestionButton")
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private func previousQuestion() {
        guard currentQuestionIndex > 0 else { return }
        currentQuestionIndex -= 1
    }
    
    private func nextQuestion() {
        guard let questionCount = quiz.questions?.count else { return }
        
        if currentQuestionIndex < questionCount - 1 {
            currentQuestionIndex += 1
        } else {
            completeQuiz()
        }
    }
    
    private func completeQuiz() {
        let score = calculateScore()
        progress = createQuizProgress(score: score)
        showingResults = true
    }
    
    private func calculateScore() -> Int16 {
        let totalQuestions = quiz.questions?.count ?? 0
        guard totalQuestions > 0 else { return 0 }
        
        let correctAnswers = selectedAnswers.filter { $0.value.isCorrect }.count
        return Int16((Double(correctAnswers) / Double(totalQuestions)) * 100)
    }
    
    private func createQuizProgress(score: Int16) -> QuizProgress {
        let progress = QuizProgress(context: viewContext)
        progress.id = UUID()
        progress.quiz = quiz
        progress.score = score
        progress.completedAt = Date()
        progress.attemptCount = (quiz.userProgress?.attemptCount ?? 0) + 1
        
        do {
            try viewContext.save()
        } catch {
            ZeezLogger.error(ZeezLogger.learning, "Error saving quiz progress", error: error)
        }
        
        return progress
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let quiz = Quiz(context: context)
    quiz.title = "Sample Quiz"
    quiz.passingScore = 70
    return NavigationView {
        LearnQuizView(quiz: quiz)
            .environment(\.managedObjectContext, context)
    }
}
