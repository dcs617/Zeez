import SwiftUI
import CoreData

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
                
                Picker("Category", selection: $selectedCategory) {
                    ForEach(NoteCategory.allCases, id: \.self) { category in
                        Label(category.rawValue, systemImage: category.icon)
                            .foregroundColor(category.color)
                            .tag(category)
                    }
                }
            }
            
            Section {
                TextEditor(text: $content)
                    .frame(minHeight: 200)
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
                }
            }
            
            Section {
                Button(action: saveNote) {
                    Label("Save Note", systemImage: "square.and.pencil")
                }
            }
        }
        .navigationTitle(article != nil ? "Article Note" : "New Note")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }
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
            print("Error saving note: \(error)")
        }
    }
}

#Preview {
    NavigationView {
        LearnNoteView(article: nil)
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}