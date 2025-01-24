import SwiftUI
import CoreData

struct PathProgressView: View {
    @Environment(\.managedObjectContext) private var viewContext
    let pathId: String
    @State private var progress: Double = 0
    
    var body: some View {
        VStack(spacing: 8) {
            ProgressView(value: progress)
                .tint(.blue)
            
            HStack {
                Text("\(Int(progress * 100))% Complete")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let nextArticle = LearningPathManager.shared.getNextModule(
                    forPath: pathId,
                    context: viewContext
                ) {
                    NavigationLink(destination: LearnArticleDetailView(articleId: nextArticle.objectID)) {
                        Label("Continue", systemImage: "arrow.right")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .onAppear {
            updateProgress()
        }
    }
    
    private func updateProgress() {
        progress = LearningPathManager.shared.calculatePathProgress(
            pathId: pathId,
            context: viewContext
        )
    }
}

#Preview {
    PathProgressView(pathId: "basics")
        .padding()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
