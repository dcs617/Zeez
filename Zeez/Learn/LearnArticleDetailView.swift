import SwiftUI
import CoreData
import os.log

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
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Article content")
                    .accessibilityHint("Main article text with highlighting capabilities")
                    .accessibilityIdentifier("articleContent")
                    
                    if let highlights = article.highlights {
                        Divider()
                        highlightsSection(highlights: [highlights])
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
                            .accessibilityLabel("View highlights")
                            .accessibilityHint("Open highlights list for this article")
                            .accessibilityIdentifier("viewHighlightsButton")
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .accessibilityLabel("Article options")
                        .accessibilityHint("Show additional article options")
                        .accessibilityIdentifier("articleOptionsMenu")
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
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Article not found")
            .accessibilityHint("This article may have been removed or is temporarily unavailable")
            .accessibilityIdentifier("articleNotFoundView")
        }
    }
    
    private func articleHeader(_ article: LearnArticle) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(article.title ?? "")
                .font(.title)
                .fontWeight(.bold)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel("Article title: \(article.title ?? "Untitled")")
                .accessibilityIdentifier("articleTitle")
            
            HStack {
                Label("\(article.readTimeMinutes) min read", systemImage: "clock")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .accessibilityLabel("Reading time: \(article.readTimeMinutes) minutes")
                    .accessibilityHint("Estimated time to read this article")
                    .accessibilityIdentifier("readingTime")
                
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
                .accessibilityLabel("See all highlights")
                .accessibilityHint("View complete list of highlights for this article")
                .accessibilityIdentifier("seeAllHighlightsButton")
            }
            
            ForEach(highlights.prefix(3)) { highlight in
                highlightPreview(highlight)
                    .onTapGesture {
                        selectedHighlight = highlight
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Highlight: \(highlight.text?.prefix(50) ?? "No text")")
                    .accessibilityHint("Double tap to view or edit this highlight")
                    .accessibilityIdentifier("highlightPreview_\(highlight.id?.uuidString ?? "unknown")")
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
                .accessibilityLabel("View note")
                .accessibilityHint("Navigate to detailed note view")
                .accessibilityIdentifier("viewNoteLink")
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
            let progress = LearningPathManager.shared.calculatePathProgress(pathId: category, context: viewContext)
            ZeezLogger.learning.debug("Updated learning path '\(category)' progress to \(String(format: "%.1f", progress * 100))%")
        }
    }
}

struct ArticleHighlightsList: View {
    let article: LearnArticle
    @Environment(\.dismiss) private var dismiss
    @State private var selectedHighlight: NoteHighlight?
    
    var body: some View {
        List {
            if let highlights = article.highlights {
                ForEach([highlights]) { highlight in
                    highlightRow(highlight)
                        .onTapGesture {
                            selectedHighlight = highlight
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Highlight: \(highlight.text?.prefix(50) ?? "No text")")
                        .accessibilityHint("Double tap to view or edit this highlight")
                        .accessibilityIdentifier("highlightRow_\(highlight.id?.uuidString ?? "unknown")")
                }
            }
        }
        .accessibilityLabel("Highlights list")
        .accessibilityHint("List of all highlights from this article")
        .accessibilityIdentifier("highlightsList")
        .navigationTitle("Highlights")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }
                .accessibilityLabel("Done")
                .accessibilityHint("Close highlights list")
                .accessibilityIdentifier("highlightsListDoneButton")
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
                    .accessibilityLabel("View note")
                    .accessibilityHint("Navigate to detailed note view")
                    .accessibilityIdentifier("highlightRowViewNoteLink")
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
