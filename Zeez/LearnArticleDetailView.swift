import SwiftUI
import CoreData

struct LearnArticleDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    let articleId: NSManagedObjectID
    @State private var showingHighlights = false
    @State private var selectedHighlight: NoteHighlight?
    @StateObject private var highlightManager = LearnHighlightManager()
    @State private var hasMarkedAsRead = false
    
    var body: some View {
        if let article = fetchArticle() {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    articleHeader(article)
                    
                    LearnHighlightableText(
                        text: article.content ?? "",
                        articleId: articleId
                    )
                    .font(.body)
                    .lineSpacing(4)
                    
                    if let highlights = article.highlights,
                       let highlightSet = highlights as? Set<NoteHighlight>,
                       !highlightSet.isEmpty {
                        Divider()
                        highlightsSection(highlights: Array(highlightSet))
                    }
                    
                    if article.quiz != nil {
                        Divider()
                        LearnQuizSection(article: article)
                    }
                    
                    if let references = article.references,
                       let referenceSet = references as? Set<ScientificReference>,
                       !referenceSet.isEmpty {
                        Divider()
                        LearnArticleReferenceSection(article: article)
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        LearnBookmarkButton(article: article)
                        
                        Menu {
                            Button(action: { showingHighlights = true }) {
                                Label("View Highlights", systemImage: "highlighter")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingHighlights) {
                NavigationView {
                    ArticleHighlightsList(article: article)
                }
            }
            .sheet(item: $selectedHighlight) { highlight in
                NavigationView {
                    LearnNoteView(article: article, content: highlight.text ?? "")
                }
            }
            .onAppear {
                markArticleAsRead(article)
            }
        } else {
            ContentUnavailableView(
                "Article Not Found",
                systemImage: "doc.questionmark",
                description: Text("This article may have been removed or is temporarily unavailable.")
            )
        }
    }
    
    private func articleHeader(_ article: LearnArticle) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(article.title ?? "")
                .font(.title)
                .fontWeight(.bold)
            
            HStack {
                Label("\(article.readTimeMinutes) min read", systemImage: "clock")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let references = article.references,
                   let referenceSet = references as? Set<ScientificReference>,
                   !referenceSet.isEmpty {
                    LearnReferenceCounter(count: referenceSet.count)
                }
            }
            
            LearnReadingControls(article: article)
            
            Divider()
        }
    }
    
    private func highlightsSection(highlights: [NoteHighlight]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Highlights")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { showingHighlights = true }) {
                    Text("See All")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            
            ForEach(highlights.prefix(3)) { highlight in
                highlightPreview(highlight)
                    .onTapGesture {
                        selectedHighlight = highlight
                    }
            }
        }
    }
    
    private func highlightPreview(_ highlight: NoteHighlight) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let color = highlight.color,
               let highlightColor = LearnHighlightManager.HighlightColor(rawValue: color) {
                Text(highlight.text ?? "")
                    .font(.subheadline)
                    .padding(8)
                    .background(highlightColor.color)
                    .cornerRadius(4)
            }
            
            if let date = highlight.createdAt {
                Text(date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let note = highlight.note {
                NavigationLink(destination: LearnNoteDetailView(note: note)) {
                    Label("View Note", systemImage: "note.text")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func fetchArticle() -> LearnArticle? {
        viewContext.object(with: articleId) as? LearnArticle
    }
    
    private func markArticleAsRead(_ article: LearnArticle) {
        guard !hasMarkedAsRead else { return }
        
        if article.userProgress == nil {
            let progress = UserArticleProgress(context: viewContext)
            progress.id = UUID()
            progress.article = article
            progress.lastReadDate = Date()
            progress.isCompleted = true
        } else {
            article.userProgress?.lastReadDate = Date()
            article.userProgress?.isCompleted = true
        }
        
        try? viewContext.save()
        hasMarkedAsRead = true
        
        if let category = article.category {
            LearningPathManager.shared.calculatePathProgress(pathId: category, context: viewContext)
        }
    }
}

struct ArticleHighlightsList: View {
    let article: LearnArticle
    @Environment(\.dismiss) private var dismiss
    @State private var selectedHighlight: NoteHighlight?
    
    var body: some View {
        List {
            if let highlights = article.highlights,
               let highlightSet = highlights as? Set<NoteHighlight> {
                ForEach(Array(highlightSet)) { highlight in
                    highlightRow(highlight)
                        .onTapGesture {
                            selectedHighlight = highlight
                        }
                }
            }
        }
        .navigationTitle("Highlights")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .sheet(item: $selectedHighlight) { highlight in
            NavigationView {
                LearnNoteView(article: article, content: highlight.text ?? "")
            }
        }
    }
    
    private func highlightRow(_ highlight: NoteHighlight) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let color = highlight.color,
               let highlightColor = LearnHighlightManager.HighlightColor(rawValue: color) {
                Text(highlight.text ?? "")
                    .font(.body)
                    .padding(8)
                    .background(highlightColor.color)
                    .cornerRadius(4)
            }
            
            HStack {
                if let date = highlight.createdAt {
                    Text(date, style: .date)
                }
                
                Spacer()
                
                if let note = highlight.note {
                    NavigationLink(destination: LearnNoteDetailView(note: note)) {
                        Label("View Note", systemImage: "note.text")
                    }
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let article = LearnArticle(context: context)
    article.title = "Sample Article"
    article.content = "This is a sample article content."
    article.readTimeMinutes = 5
    return NavigationView {
        LearnArticleDetailView(articleId: article.objectID)
            .environment(\.managedObjectContext, context)
    }
}