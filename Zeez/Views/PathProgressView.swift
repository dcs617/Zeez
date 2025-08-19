import SwiftUI
import CoreData
import os.log

struct PathProgressView: View {
    @Environment(\.managedObjectContext) private var viewContext
    let pathId: String
    @State private var progress: Double = 0
    
    var body: some View {
        VStack(spacing: 8) {
            ProgressView(value: progress)
                .tint(.blue)
                .accessibilityLabel("Learning path progress: \(Int(progress * 100)) percent complete")
                .accessibilityIdentifier("pathProgressBar")
            
            HStack {
                Text("\(Int(progress * 100))% Complete")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityLabel("\(Int(progress * 100)) percent complete")
                    .accessibilityIdentifier("progressPercentage")
                
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
                    .accessibilityLabel("Continue learning path")
                    .accessibilityHint("Navigate to next article in learning path")
                    .accessibilityIdentifier("continuePathButton")
                }
            }
        }
        .onAppear {
            updateProgress()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pathProgressView")
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
