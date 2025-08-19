import SwiftUI
import CoreData
import os.log

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
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Bookmarks view")
        .accessibilityHint("View and manage your bookmarked articles")
        .accessibilityIdentifier("bookmarksView")
    }
    
    private var emptyState: some View {
        ContentUnavailableView(
            "No Bookmarks",
            systemImage: "bookmark",
            description: Text("Bookmark articles to save them for later.")
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No bookmarks")
        .accessibilityHint("You haven't bookmarked any articles yet. Bookmark articles to save them for later")
        .accessibilityIdentifier("noBookmarksEmptyState")
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
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Bookmarked article: \(article.title ?? "Untitled"), \(progress.isCompleted ? "Read" : "Unread")")
                        .accessibilityHint("Double tap to read this bookmarked article")
                        .accessibilityIdentifier("bookmarkedArticle_\(article.title?.replacingOccurrences(of: " ", with: "_") ?? "untitled")")
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                removeBookmark(progress)
                            } label: {
                                Label("Remove", systemImage: "bookmark.slash")
                            }
                            .accessibilityLabel("Remove bookmark")
                            .accessibilityHint("Remove this article from bookmarks")
                            .accessibilityIdentifier("removeBookmarkButton")
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
            ZeezLogger.error(ZeezLogger.learning, "Error removing bookmark", error: error)
        }
    }
}

#Preview {
    NavigationView {
        LearnBookmarksView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
