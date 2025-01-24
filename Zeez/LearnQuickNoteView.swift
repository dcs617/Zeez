import SwiftUI
import CoreData

struct LearnQuickNoteView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var content = ""
    @State private var title = ""
    @State private var isPinned = false
    @State private var position = CGPoint(x: UIScreen.main.bounds.width - 250, y: 100)
    @State private var dragOffset: CGSize = .zero
    @State private var isExpanded = false
    @State private var category: LearnNoteView.NoteCategory = .general
    @State private var showingRelatedContent = false
    @State private var showingCategories = false
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            if isExpanded {
                noteEditor
            }
        }
        .frame(width: 300)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 5)
        .position(x: position.x + dragOffset.width, y: position.y + dragOffset.height)
        .gesture(dragGesture)
        .sheet(isPresented: $showingRelatedContent) {
            NavigationView {
                RelatedContentView(noteContent: content)
            }
        }
    }
    
    private var header: some View {
        HStack {
            Button(action: { isExpanded.toggle() }) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Image(systemName: category.icon)
                    .foregroundColor(category.color)
                Text("Quick Note")
                    .font(.headline)
            }
            .onTapGesture {
                showingCategories.toggle()
            }
            .popover(isPresented: $showingCategories) {
                categoryPicker
            }
            
            Spacer()
            
            Button(action: { isPinned.toggle() }) {
                Image(systemName: isPinned ? "pin.fill" : "pin")
                    .foregroundColor(isPinned ? .blue : .secondary)
            }
            
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
    }
    
    private var noteEditor: some View {
        VStack(spacing: 8) {
            TextField("Title (optional)", text: $title)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal, 8)
                .padding(.top, 8)
            
            TextEditor(text: $content)
                .frame(height: 150)
                .padding(8)
            
            Divider()
            
            HStack {
                Menu {
                    Button(action: saveNote) {
                        Label("Save Note", systemImage: "square.and.arrow.down")
                    }
                    
                    Button(action: saveAndEdit) {
                        Label("Save and Continue Editing", systemImage: "pencil")
                    }
                    
                    if !content.isEmpty {
                        Button(action: { showingRelatedContent = true }) {
                            Label("Find Related Content", systemImage: "book.fill")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .disabled(content.isEmpty)
                
                Spacer()
                
                Button(action: saveNote) {
                    Label("Save", systemImage: "square.and.arrow.down")
                        .font(.subheadline)
                }
                .buttonStyle(.borderedProminent)
                .disabled(content.isEmpty)
                
                Button(action: { content = ""; title = "" }) {
                    Label("Clear", systemImage: "trash")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .disabled(content.isEmpty)
            }
            .padding(8)
        }
    }
    
    private var categoryPicker: some View {
        List(LearnNoteView.NoteCategory.allCases, id: \.self) { cat in
            Button(action: { 
                category = cat
                showingCategories = false
            }) {
                HStack {
                    Image(systemName: cat.icon)
                        .foregroundColor(cat.color)
                    Text(cat.rawValue)
                    Spacer()
                    if category == cat {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .frame(width: 200)
    }
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if !isPinned {
                    dragOffset = value.translation
                }
            }
            .onEnded { value in
                if !isPinned {
                    position.x += value.translation.width
                    position.y += value.translation.height
                    dragOffset = .zero
                    
                    // Keep within screen bounds
                    let screen = UIScreen.main.bounds
                    position.x = min(max(150, position.x), screen.width - 150)
                    position.y = min(max(100, position.y), screen.height - 100)
                }
            }
    }
    
    private func saveNote() {
        createNote()
        content = ""
        title = ""
        
        // Optional: show success feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    private func saveAndEdit() {
        let note = createNote()
        content = ""
        title = ""
        showNoteDetail(note)
    }
    
    @discardableResult
    private func createNote() -> SleepNote {
        let note = SleepNote(context: viewContext)
        note.id = UUID()
        note.content = content
        note.createdAt = Date()
        note.modifiedAt = Date()
        note.category = category.rawValue
        note.title = title.isEmpty ? 
            "Quick Note - \(Date().formatted(date: .abbreviated, time: .shortened))" : 
            title
        
        do {
            try viewContext.save()
        } catch {
            print("Error saving quick note: \(error)")
        }
        
        return note
    }
    
    private func showNoteDetail(_ note: SleepNote) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            let detailView = NavigationView {
                LearnNoteDetailView(note: note)
            }
            let hostingController = UIHostingController(rootView: detailView)
            rootViewController.present(hostingController, animated: true)
        }
    }
}

struct RelatedContentView: View {
    let noteContent: String
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            RelatedArticlesView(noteContent: noteContent)
                .tabItem {
                    Label("Articles", systemImage: "book.fill")
                }
                .tag(0)
            
            NotesSelectionView(onNoteSelected: { _ in })
                .tabItem {
                    Label("Notes", systemImage: "note.text")
                }
                .tag(1)
        }
        .navigationTitle("Related Content")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }
}

#Preview {
    LearnQuickNoteView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}