import SwiftUI
import CoreData

struct LearnBookmarksView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest<UserArticleProgress>(
        entity: UserArticleProgress.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \UserArticleProgress.lastReadDate, ascending: false)],
        predicate: NSPredicate(format: "bookmarked == YES"),
        animation: .default
    ) private var bookmarkedProgress
    
    var body: some View {
        Group {
            if bookmarkedProgress.count == 0 {
                emptyState
            } else {
                bookmarksList
            }
        }
        .navigationTitle("Bookmarks")
    }
    
    private var emptyState: some View {
        ContentUnavailableView(
            "No Bookmarks",
            systemImage: "bookmark",
            description: Text("Bookmark articles to save them for later.")
        )
    }
    
    private var bookmarksList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(bookmarkedProgress), id: \.self) { progress in
                    if let article = progress.article {
                        NavigationLink(destination: LearnArticleDetailView(articleId: article.objectID)) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(article.title ?? "")
                                    .font(.headline)
                                
                                HStack {
                                    if let category = article.category {
                                        Text(category)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if let date = progress.lastReadDate {
                                        Text(date, style: .date)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                if progress.isCompleted {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                        Text("Read")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                removeBookmark(progress)
                            } label: {
                                Label("Remove", systemImage: "bookmark.slash")
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private func removeBookmark(_ progress: UserArticleProgress) {
        progress.bookmarked = false
        
        do {
            try viewContext.save()
        } catch {
            print("Error removing bookmark: \(error)")
        }
    }
}

#Preview {
    NavigationView {
        LearnBookmarksView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}