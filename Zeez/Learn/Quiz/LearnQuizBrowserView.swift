import SwiftUI
import CoreData
import os.log

struct LearnQuizBrowserView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest<Quiz>(
        sortDescriptors: [NSSortDescriptor(keyPath: \Quiz.title, ascending: true)],
        animation: .default
    ) private var quizzes: FetchedResults<Quiz>
    
    @State private var selectedFilter: QuizFilter = .all
    @State private var showingQuiz: Quiz?
    
    private enum QuizFilter {
        case all
        case notStarted
        case inProgress
        case completed
        
        var title: String {
            switch self {
            case .all: return "All"
            case .notStarted: return "Not Started"
            case .inProgress: return "In Progress"
            case .completed: return "Completed"
            }
        }
    }
    
    private var quizArray: [Quiz] {
        Array(quizzes)
    }
    
    private var filteredQuizzes: [Quiz] {
        quizArray.filter { quiz in
            switch selectedFilter {
            case .all:
                return true
            case .notStarted:
                return quiz.userProgress == nil
            case .inProgress:
                guard let progress = quiz.userProgress else { return false }
                return !progress.isCompleted && progress.score < quiz.passingScore
            case .completed:
                guard let progress = quiz.userProgress else { return false }
                return progress.score >= quiz.passingScore
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            filterPicker
            
            if filteredQuizzes.isEmpty {
                emptyState
            } else {
                quizList
            }
        }
        .navigationTitle("All Quizzes")
        .fullScreenCover(item: $showingQuiz) { quiz in
            NavigationView {
                LearnQuizView(quiz: quiz)
            }
        }
    }
    
    private var filterPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach([QuizFilter.all, .notStarted, .inProgress, .completed], id: \.title) { filter in
                    filterButton(for: filter)
                }
            }
            .padding()
        }
    }
    
    private func filterButton(for filter: QuizFilter) -> some View {
        Button(action: { selectedFilter = filter }) {
            Text(filter.title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(selectedFilter == filter ? Color.blue : Color(.systemGray6))
                )
                .foregroundColor(selectedFilter == filter ? .white : .primary)
        }
        .accessibilityLabel("Filter by \(filter.title.lowercased()) quizzes")
        .accessibilityHint(selectedFilter == filter ? "Currently selected filter" : "Filter quizzes by \(filter.title.lowercased()) status")
        .accessibilityIdentifier("quizFilter\(filter.title.replacingOccurrences(of: " ", with: ""))")
    }
    
    private var quizList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredQuizzes) { quiz in
                    QuizCard(quiz: quiz)
                        .onTapGesture {
                            showingQuiz = quiz
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Quiz: \(quiz.title ?? "Unknown")")
                        .accessibilityHint("Open quiz with \(quiz.questions?.count ?? 0) questions")
                        .accessibilityIdentifier("quizCard_\(quiz.title?.replacingOccurrences(of: " ", with: "_") ?? "unknown")")
                }
            }
            .padding()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 48))
                .foregroundColor(.gray)
                .accessibilityLabel("No quizzes available")
            
            Text(emptyStateMessage)
                .font(.headline)
            
            Text(emptyStateDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(emptyStateMessage). \(emptyStateDescription)")
        .accessibilityIdentifier("quizBrowserEmptyState")
    }
    
    private var emptyStateMessage: String {
        switch selectedFilter {
        case .all:
            return "No Quizzes Available"
        case .notStarted:
            return "All Quizzes Started"
        case .inProgress:
            return "No Quizzes In Progress"
        case .completed:
            return "No Quizzes Completed"
        }
    }
    
    private var emptyStateDescription: String {
        switch selectedFilter {
        case .all:
            return "Check back later for new quizzes"
        case .notStarted:
            return "You've started all available quizzes"
        case .inProgress:
            return "Complete quizzes to track your progress"
        case .completed:
            return "Take some quizzes to see your results here"
        }
    }
}

struct QuizCard: View {
    let quiz: Quiz
    @FetchRequest private var progress: FetchedResults<QuizProgress>
    
    private var progressArray: [QuizProgress] {
        Array(progress)
    }
    
    init(quiz: Quiz) {
        self.quiz = quiz
        _progress = FetchRequest<QuizProgress>(
            sortDescriptors: [NSSortDescriptor(keyPath: \QuizProgress.completedAt, ascending: false)],
            predicate: NSPredicate(format: "quiz == %@", quiz)
        )
    }
    
    private var bestScore: Int16 {
        progressArray.map(\.score).max() ?? 0
    }
    
    private var hasPassed: Bool {
        bestScore >= quiz.passingScore
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(quiz.title ?? "")
                    .font(.headline)
                
                Spacer()
                
                if !progressArray.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: hasPassed ? "checkmark.seal.fill" : "seal.fill")
                            .foregroundColor(hasPassed ? .green : .orange)
                            .accessibilityLabel(hasPassed ? "Passed" : "Not passed")
                        Text("\(bestScore)%")
                            .font(.subheadline)
                            .foregroundColor(hasPassed ? .green : .orange)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Best score: \(bestScore) percent, \(hasPassed ? "passed" : "not passed")")
                }
            }
            
            if let description = quiz.quizDescription, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            HStack {
                Label("\(quiz.questions?.count ?? 0) Questions", systemImage: "list.bullet")
                    .accessibilityLabel("\(quiz.questions?.count ?? 0) questions")
                Spacer()
                Label("Pass: \(quiz.passingScore)%", systemImage: "checkmark.circle")
                    .accessibilityLabel("Passing score: \(quiz.passingScore) percent")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    NavigationView {
        LearnQuizBrowserView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
