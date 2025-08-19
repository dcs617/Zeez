import SwiftUI
import CoreData
import os.log

struct LearnNoteView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let article: LearnArticle?
    let initialContent: String
    @State private var title = ""
    @State private var content: String
    @State private var selectedCategory: NoteCategory = .general
    
    init(article: LearnArticle? = nil, content: String = "") {
        self.article = article
        self.initialContent = content
        self._content = State(initialValue: content)
    }
    
    enum NoteCategory: String, CaseIterable {
        case general = "General"
        case insight = "Insight"
        case question = "Question"
        case reminder = "Reminder"
        case summary = "Summary"
        
        var icon: String {
            switch self {
            case .general: return "note.text"
            case .insight: return "lightbulb"
            case .question: return "questionmark.circle"
            case .reminder: return "bell"
            case .summary: return "list.bullet"
            }
        }
        
        var color: Color {
            switch self {
            case .general: return .blue
            case .insight: return .yellow
            case .question: return .purple
            case .reminder: return .red
            case .summary: return .green
            }
        }
    }
    
    var body: some View {
        Form {
            Section {
                TextField("Title", text: $title)
                    .accessibilityLabel("Note title")
                    .accessibilityHint("Enter a title for your note")
                    .accessibilityIdentifier("noteTitleField")
                
                Picker("Category", selection: $selectedCategory) {
                    ForEach(NoteCategory.allCases, id: \.self) { category in
                        Label(category.rawValue, systemImage: category.icon)
                            .foregroundColor(category.color)
                            .tag(category)
                            .accessibilityLabel("\(category.rawValue) category")
                            .accessibilityIdentifier("noteCategory_\(category.rawValue.lowercased())")
                    }
                }
                .accessibilityLabel("Note category")
                .accessibilityHint("Select a category for your note")
                .accessibilityIdentifier("noteCategoryPicker")
            }
            
            Section {
                TextEditor(text: $content)
                    .frame(minHeight: 200)
                    .accessibilityLabel("Note content")
                    .accessibilityHint("Enter the content of your note")
                    .accessibilityIdentifier("noteContentEditor")
            }
            
            if let article = article {
                Section("Referenced Article") {
                    NavigationLink(destination: LearnArticleDetailView(articleId: article.objectID)) {
                        VStack(alignment: .leading) {
                            Text(article.title ?? "")
                                .font(.headline)
                            Text("Tap to view article")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .accessibilityLabel("Referenced article: \(article.title ?? "")")
                    .accessibilityHint("Navigate to view the referenced article")
                    .accessibilityIdentifier("referencedArticleLink")
                }
            }
            
            Section {
                Button(action: saveNote) {
                    Label("Save Note", systemImage: "square.and.pencil")
                }
                .accessibilityLabel("Save note")
                .accessibilityHint("Save this note to your collection")
                .accessibilityIdentifier("saveNoteButton")
            }
        }
        .navigationTitle(article != nil ? "Article Note" : "New Note")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }
                    .accessibilityLabel("Cancel note creation")
                    .accessibilityIdentifier("cancelNoteCreation")
            }
        }
        .onAppear {
            if !initialContent.isEmpty && title.isEmpty {
                title = "Note - \(Date().formatted(date: .abbreviated, time: .shortened))"
            }
        }
    }
    
    private func saveNote() {
        let note = SleepNote(context: viewContext)
        note.id = UUID()
        note.title = title
        note.content = content
        note.category = selectedCategory.rawValue
        note.createdAt = Date()
        note.modifiedAt = Date()
        note.article = article
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            ZeezLogger.error(ZeezLogger.learning, "Error saving note", error: error)
        }
    }
}

#Preview {
    NavigationView {
        LearnNoteView(article: nil)
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
