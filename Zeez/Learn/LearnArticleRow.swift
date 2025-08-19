import SwiftUI
import CoreData
import os.log

struct LearnArticleRow: View {
    let article: LearnArticle
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                if let imageName = article.imageAssetName {
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(article.title ?? "")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if article.quiz != nil {
                            LearnArticleQuizBadge(quiz: article.quiz)
                        }
                    }
                    
                    HStack {
                        Image(systemName: "book")
                        Text("\(article.readTimeMinutes) min read")
                        
                        if let progress = article.userProgress, progress.isCompleted {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let article = LearnArticle(context: context)
    article.title = "Sample Article"
    article.readTimeMinutes = 5
    return LearnArticleRow(article: article) {}
        .padding()
        .environment(\.managedObjectContext, context)
}
