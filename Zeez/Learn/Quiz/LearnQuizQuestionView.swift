import SwiftUI
import CoreData
import os.log

struct QuizQuestionView: View {
    let question: QuizQuestion
    let selectedAnswer: QuizAnswer?
    let onAnswerSelected: (QuizAnswer) -> Void
    
    @State private var isAnimating = false
    
    private var answers: [QuizAnswer] {
        (question.answers?.allObjects as? [QuizAnswer])?
            .sorted { $0.id?.uuidString ?? "" < $1.id?.uuidString ?? "" } ?? []
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                questionContent
                answersSection
            }
            .padding()
            .opacity(isAnimating ? 1 : 0)
            .offset(x: isAnimating ? 0 : 50)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                isAnimating = true
            }
        }
        .onDisappear {
            isAnimating = false
        }
    }
    
    private var questionContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(question.question ?? "")
                .font(.title3)
                .fontWeight(.semibold)
                .accessibilityLabel("Question: \(question.question ?? "No question text")")
                .accessibilityIdentifier("quizQuestion")
            
            if let explanation = question.explanation {
                Text(explanation)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .accessibilityLabel("Explanation: \(explanation)")
                    .accessibilityIdentifier("questionExplanation")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("questionContent")
    }
    
    private var answersSection: some View {
        VStack(spacing: 12) {
            ForEach(answers) { answer in
                AnswerButton(
                    answer: answer,
                    isSelected: selectedAnswer == answer,
                    onTap: { onAnswerSelected(answer) }
                )
            }
        }
    }
}

struct AnswerButton: View {
    let answer: QuizAnswer
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(answer.text ?? "")
                    .font(.body)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .accessibilityLabel(isSelected ? "Selected" : "Not selected")
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Answer option: \(answer.text ?? "Unknown answer")")
        .accessibilityHint(isSelected ? "Currently selected answer" : "Select this answer option")
        .accessibilityIdentifier("answerOption_\(answer.text?.prefix(20).replacingOccurrences(of: " ", with: "_") ?? "unknown")")
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let question = QuizQuestion(context: context)
    question.question = "What is the primary function of REM sleep?"
    return QuizQuestionView(
        question: question,
        selectedAnswer: nil,
        onAnswerSelected: { _ in }
    )
    .padding()
}
