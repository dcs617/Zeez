import SwiftUI
import CoreData

struct LearnNoteDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var note: SleepNote
    
    @State private var isEditing = false
    @State private var editedContent: String = ""
    @State private var editedTitle: String = ""
    @State private var editedCategory: LearnNoteView.NoteCategory = .general
    @State private var showingNoteLinking = false
    @State private var showingDeleteAlert = false
    @State private var showingShareSheet = false
    @State private var showingArticleBrowser = false
    @State private var showingRelatedArticles = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if isEditing {
                    editingView
                } else {
                    displayView
                }
                
                if note.article == nil {
                    articleSuggestionsSection
                }
                
                if let content = note.content,
                   !content.isEmpty,
                   !isEditing {
                    relatedArticlesSection
                }
            }
            .padding()
        }
        .navigationTitle(isEditing ? "Edit Note" : (note.title ?? "Note"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    if isEditing {
                        Button("Done") { toggleEdit() }
                    } else {
                        Button("Edit") { toggleEdit() }
                        
                        Menu {
                            if note.article == nil {
                                Button(action: { showingArticleBrowser = true }) {
                                    Label("Link to Article", systemImage: "book")
                                }
                            }
                            
                            Button(action: { showingNoteLinking = true }) {
                                Label("Link Notes", systemImage: "link")
                            }
                            Button(action: { showingShareSheet = true }) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            Button(role: .destructive, action: { showingDeleteAlert = true }) {
                                Label("Delete", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
        .alert("Delete Note", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive, action: deleteNote)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this note? This action cannot be undone.")
        }
        .sheet(isPresented: $showingNoteLinking) {
            LearnNoteLinker(currentNote: note)
        }
        .sheet(isPresented: $showingShareSheet) {
            LearnNoteShareView(notes: [note])
        }
        .sheet(isPresented: $showingArticleBrowser) {
            NavigationView {
                LearnArticleListView(category: .basics) { articleId in
                    linkToArticle(articleId: articleId)
                }
            }
        }
        .sheet(isPresented: $showingRelatedArticles) {
            NavigationView {
                RelatedArticlesView(noteContent: note.content ?? "")
            }
        }
    }
    
    private var displayView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                if let category = note.category,
                   let noteCategory = LearnNoteView.NoteCategory(rawValue: category) {
                    Label(noteCategory.rawValue, systemImage: noteCategory.icon)
                        .font(.subheadline)
                        .foregroundColor(noteCategory.color)
                }
                
                Spacer()
                
                if let date = note.modifiedAt {
                    Text(date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let content = note.content {
                Text(content)
                    .font(.body)
            }
            
            if let article = note.article {
                NavigationLink(destination: LearnArticleDetailView(articleId: article.objectID)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Referenced Article")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(article.title ?? "")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
            
            if let linkedNotes = note.linkedNotes as? Set<SleepNote>, !linkedNotes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Linked Notes")
                        .font(.headline)
                    
                    ForEach(Array(linkedNotes)) { linkedNote in
                        NavigationLink(destination: LearnNoteDetailView(note: linkedNote)) {
                            HStack {
                                Text(linkedNote.title ?? "")
                                    .font(.subheadline)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                }
            }
        }
    }
    
    private var editingView: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Title", text: $editedTitle)
                .font(.headline)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Picker("Category", selection: $editedCategory) {
                ForEach(LearnNoteView.NoteCategory.allCases, id: \.self) { category in
                    Label(category.rawValue, systemImage: category.icon)
                        .foregroundColor(category.color)
                        .tag(category)
                }
            }
            
            TextEditor(text: $editedContent)
                .frame(minHeight: 200)
                .border(Color(.systemGray4))
        }
    }
    
    private var articleSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add Learning Context")
                .font(.headline)
            
            Button(action: { showingArticleBrowser = true }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Link to an Article")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        
                        Text("Connect this note with sleep learning content")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.blue)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
    
    private var relatedArticlesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Related Content")
                .font(.headline)
            
            Button(action: { showingRelatedArticles = true }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("View Related Articles")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        
                        Text("Find articles related to your notes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.blue)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
    
    private func toggleEdit() {
        if isEditing {
            // Save changes
            note.title = editedTitle
            note.content = editedContent
            note.category = editedCategory.rawValue
            note.modifiedAt = Date()
            
            do {
                try viewContext.save()
            } catch {
                print("Error saving note: \(error)")
            }
        } else {
            // Load current values
            editedTitle = note.title ?? ""
            editedContent = note.content ?? ""
            editedCategory = LearnNoteView.NoteCategory(rawValue: note.category ?? "") ?? .general
        }
        
        isEditing.toggle()
    }
    
    private func deleteNote() {
        viewContext.delete(note)
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error deleting note: \(error)")
        }
    }
    
    private func linkToArticle(articleId: NSManagedObjectID) {
        guard let article = viewContext.object(with: articleId) as? LearnArticle else { return }
        note.article = article
        note.modifiedAt = Date()
        
        do {
            try viewContext.save()
            showingArticleBrowser = false
        } catch {
            print("Error linking article: \(error)")
        }
    }
}

struct RelatedArticlesView: View {
    let noteContent: String
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @FetchRequest<LearnArticle> var articles: FetchedResults<LearnArticle>
    
    init(noteContent: String) {
        self.noteContent = noteContent
        let words = noteContent.components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count >= 4 }
            .prefix(5)
            .joined(separator: " OR ")
        
        _articles = FetchRequest(
            entity: LearnArticle.entity(),
            sortDescriptors: [NSSortDescriptor(keyPath: \LearnArticle.title, ascending: true)],
            predicate: NSPredicate(format: "content CONTAINS[cd] %@", words)
        )
    }
    
    var body: some View {
        List {
            if articles.isEmpty {
                Text("No related articles found")
                    .foregroundColor(.secondary)
            } else {
                ForEach(articles) { article in
                    NavigationLink(destination: LearnArticleDetailView(articleId: article.objectID)) {
                        LearnArticleRow(article: article) {}
                    }
                }
            }
        }
        .navigationTitle("Related Articles")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let note = SleepNote(context: context)
    note.title = "Sample Note"
    note.content = "This is a sample note content."
    return NavigationView {
        LearnNoteDetailView(note: note)
            .environment(\.managedObjectContext, context)
    }
}