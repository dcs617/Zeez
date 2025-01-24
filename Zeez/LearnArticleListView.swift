import SwiftUI
import CoreData

struct LearnArticleListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    let category: LearnCategory
    let onArticleSelected: (NSManagedObjectID) -> Void
    
    @FetchRequest private var articles: FetchedResults<LearnArticle>
    
    init(category: LearnCategory, onArticleSelected: @escaping (NSManagedObjectID) -> Void) {
        self.category = category
        self.onArticleSelected = onArticleSelected
        
        _articles = FetchRequest<LearnArticle>(
            sortDescriptors: [
                NSSortDescriptor(keyPath: \LearnArticle.sortOrder, ascending: true),
                NSSortDescriptor(keyPath: \LearnArticle.title, ascending: true)
            ],
            predicate: NSPredicate(format: "category == %@", category.rawValue)
        )
    }
    
    var body: some View {
        Group {
            if articles.isEmpty {
                emptyStateView
            } else {
                articleList
            }
        }
    }
    
    private var articleList: some View {
        ForEach(articles) { article in
            LearnArticleRow(article: article, onSelect: {
                onArticleSelected(article.objectID)
            })
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No Articles Yet")
                .font(.headline)
            
            Text("Check back soon for new content")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}