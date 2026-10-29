import SwiftUI
import CoreData
import os.log

struct LearnQuizSection: View {
    @Environment(\.managedObjectContext) private var viewContext
    let article: LearnArticle
    @State private var showingQuiz = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Knowledge Check")
                .font(.headline)
            
            if let quiz = article.quiz {
                LearnQuizStatusView(quiz: quiz) {
                    showingQuiz = true
                }
            } else {
                noQuizAvailable
            }
        }
        .fullScreenCover(isPresented: $showingQuiz) {
            if let quiz = article.quiz {
                NavigationStack {
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

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let article = LearnArticle(context: context)
    return LearnQuizSection(article: article)
        .padding()
        .environment(\.managedObjectContext, context)
}
