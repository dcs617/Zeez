import SwiftUI
import CoreData

struct LearnSearchResults: View {
    @Environment(\.managedObjectContext) private var viewContext
    let searchText: String
    
    var body: some View {
        VStack(spacing: 0) {
            if searchText.isEmpty {
                EmptySearchView()
            } else {
                SearchResultsList(searchText: searchText)
            }
        }
    }
}

private struct EmptySearchView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("Search Learn Content")
                .font(.headline)
            
            Text("Start typing to search articles, notes, and highlights")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

private struct SearchResultsList: View {
    @Environment(\.managedObjectContext) private var viewContext
    let searchText: String
    
    // Article Search
    @FetchRequest private var articles: FetchedResults<LearnArticle>
    // Notes Search
    @FetchRequest private var notes: FetchedResults<SleepNote>
    // Highlights Search
    @FetchRequest private var highlights: FetchedResults<NoteHighlight>
    
    init(searchText: String) {
        self.searchText = searchText  // Initialize the searchText property
        
        // Articles fetch request
        _articles = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \LearnArticle.title, ascending: true)],
            predicate: NSPredicate(
                format: "title CONTAINS[cd] %@ OR content CONTAINS[cd] %@",
                searchText, searchText
            )
        )
        
        // Notes fetch request
        _notes = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \SleepNote.modifiedAt, ascending: false)],
            predicate: NSPredicate(
                format: "title CONTAINS[cd] %@ OR content CONTAINS[cd] %@",
                searchText, searchText
            )
        )
        
        // Highlights fetch request
        _highlights = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \NoteHighlight.createdAt, ascending: false)],
            predicate: NSPredicate(format: "text CONTAINS[cd] %@", searchText)
        )
    }
    
    var body: some View {
        List {
            if !articles.isEmpty {
                Section("Articles") {
                    ForEach(articles) { article in
                        NavigationLink(destination: LearnArticleDetailView(articleId: article.objectID)) {
                            ArticleSearchResult(article: article, searchTerm: searchText)
                        }
                    }
                }
            }
            
            if !notes.isEmpty {
                Section("Notes") {
                    ForEach(notes) { note in
                        NavigationLink(destination: LearnNoteDetailView(note: note)) {
                            NoteSearchResult(note: note, searchTerm: searchText)
                        }
                    }
                }
            }
            
            if !highlights.isEmpty {
                Section("Highlights") {
                    ForEach(highlights) { highlight in
                        if let article = highlight.article {
                            NavigationLink(destination: LearnArticleDetailView(articleId: article.objectID)) {
                                HighlightSearchResult(highlight: highlight, searchTerm: searchText)
                            }
                        }
                    }
                }
            }
            
            if articles.isEmpty && notes.isEmpty && highlights.isEmpty {
                Text("No results found")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            }
        }
    }
}

private struct ArticleSearchResult: View {
    let article: LearnArticle
    let searchTerm: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(article.title ?? "")
                .font(.headline)
            
            if let content = article.content,
               let matchRange = content.range(of: searchTerm, options: .caseInsensitive) {
                let start = content.index(matchRange.lowerBound, offsetBy: -20, limitedBy: content.startIndex) ?? content.startIndex
                let end = content.index(matchRange.upperBound, offsetBy: 20, limitedBy: content.endIndex) ?? content.endIndex
                Text("..." + content[start..<end] + "...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            if let category = article.category {
                Text(category)
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct NoteSearchResult: View {
    let note: SleepNote
    let searchTerm: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.title ?? "")
                .font(.headline)
            
            if let content = note.content,
               let matchRange = content.range(of: searchTerm, options: .caseInsensitive) {
                let start = content.index(matchRange.lowerBound, offsetBy: -20, limitedBy: content.startIndex) ?? content.startIndex
                let end = content.index(matchRange.upperBound, offsetBy: 20, limitedBy: content.endIndex) ?? content.endIndex
                Text("..." + content[start..<end] + "...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            if let date = note.modifiedAt {
                Text(date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct HighlightSearchResult: View {
    let highlight: NoteHighlight
    let searchTerm: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(highlight.text ?? "")
                .font(.subheadline)
                .lineLimit(2)
            
            if let article = highlight.article {
                Text("From: " + (article.title ?? ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let date = highlight.createdAt {
                Text(date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationView {
        LearnSearchResults(searchText: "sleep")
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
