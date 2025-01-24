import SwiftUI
import CoreData

struct LearnQuizSection: View {
    @Environment(\.managedObjectContext) private var viewContext
    let article: LearnArticle
    @State private var showingQuiz = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Knowledge Check")
                .font(.headline)
            
            if let quiz = article.quiz {
                LearnQuizStatusView(quiz: quiz)
                    .onTapGesture {
                        showingQuiz = true
                    }
            } else {
                noQuizAvailable
            }
        }
        .fullScreenCover(isPresented: $showingQuiz) {
            if let quiz = article.quiz {
                NavigationView {
                    LearnQuizView(quiz: quiz)
                }
            }
        }
    }
    
    private var noQuizAvailable: some View {
        HStack {
            Image(systemName: "graduationcap")
                .foregroundColor(.gray)
            Text("No quiz available for this article")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// For Articles List View
struct LearnQuizIndicator: View {
    let quiz: Quiz?
    @FetchRequest private var progress: FetchedResults<QuizProgress>
    
    init(quiz: Quiz?) {
        self.quiz = quiz
        if let quiz = quiz {
            _progress = FetchRequest(
                sortDescriptors: [NSSortDescriptor(keyPath: \QuizProgress.completedAt, ascending: false)],
                predicate: NSPredicate(format: "quiz == %@", quiz)
            )
        } else {
            _progress = FetchRequest(
                sortDescriptors: [],
                predicate: NSPredicate(value: false)
            )
        }
    }
    
    private var bestScore: Int16 {
        progress.map(\.score).max() ?? 0
    }
    
    private var hasPassed: Bool {
        bestScore >= (quiz?.passingScore ?? 0)
    }
    
    var body: some View {
        if let quiz = quiz {
            HStack(spacing: 4) {
                Image(systemName: hasPassed ? "checkmark.seal.fill" : "seal")
                    .foregroundColor(hasPassed ? .green : .gray)
                    .font(.caption)
                
                if !progress.isEmpty {
                    Text("\(bestScore)%")
                        .font(.caption)
                        .foregroundColor(hasPassed ? .green : .secondary)
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
    let context = PersistenceController.preview.container.viewContext
    let article = LearnArticle(context: context)
    return LearnQuizSection(article: article)
        .padding()
        .environment(\.managedObjectContext, context)
}