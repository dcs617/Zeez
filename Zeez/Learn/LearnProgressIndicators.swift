import SwiftUI
import CoreData
import os.log

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
    LearnArticleQuizBadge(quiz: nil)
        .padding()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}

