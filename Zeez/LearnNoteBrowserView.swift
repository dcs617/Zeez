import SwiftUI
import CoreData

struct LearnNoteBrowserView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var searchText = ""
    @State private var selectedView: ViewType
    @State private var selectedSort: SortType = .date
    @State private var showingNewNote = false
    @State private var showingShareSheet = false
    @State private var showingArticleLinks = false
    @State private var selectedNotes: Set<SleepNote> = Set()
    @State private var isSelectionMode = false
    
    enum ViewType: String, CaseIterable {
        case all = "All"
        case highlights = "Highlights"
        case articles = "Article Notes"
        case quickNotes = "Quick Notes"
        
        var predicate: NSPredicate {
            switch self {
            case .all:
                return NSPredicate(value: true)
            case .highlights:
                return NSPredicate(format: "category == %@", "highlight")
            case .articles:
                return NSPredicate(format: "article != nil")
            case .quickNotes:
                return NSPredicate(format: "category == %@", "quick_note")
            }
        }
    }
    
    enum SortType: String, CaseIterable {
        case date = "Date"
        case title = "Title"
        case category = "Category"
    }
    
    init(initialFilter: ViewType = .all) {
        _selectedView = State(initialValue: initialFilter)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            searchBar
            filterBar
            notesList
            
            if selectedView == .articles {
                articleSuggestionsButton
            }
        }
        .navigationTitle("Notes")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarLeading) {
                Button(action: { isSelectionMode.toggle() }) {
                    Text(isSelectionMode ? "Done" : "Select")
                }
            }
            
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingNewNote = true }) {
                        Label("New Note", systemImage: "square.and.pencil")
                    }
                    
                    Button(action: { showingQuickNote() }) {
                        Label("Quick Note", systemImage: "bolt")
                    }
                    
                    Button(action: { showingArticleLinks = true }) {
                        Label("Link Article", systemImage: "link")
                    }
                } label: {
                    Image(systemName: "plus")
                }
                
                if isSelectionMode && !selectedNotes.isEmpty {
                    Button(action: { showingShareSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(isPresented: $showingNewNote) {
            NavigationView {
                LearnNoteView(article: nil)
            }
        }
        .sheet(isPresented: $showingArticleLinks) {
            NavigationView {
                LearnArticleListView(category: .basics) { articleId in
                    createArticleNote(articleId: articleId)
                }
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            LearnNoteShareView(notes: Array(selectedNotes))
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search notes", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .padding()
    }
    
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ViewType.allCases, id: \.self) { type in
                    filterButton(for: type)
                }
                
                Menu {
                    ForEach(SortType.allCases, id: \.self) { type in
                        Button(type.rawValue) {
                            selectedSort = type
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
    
    private var articleSuggestionsButton: some View {
        NavigationLink(destination: LearnArticleListView(category: .basics) { articleId in
            createArticleNote(articleId: articleId)
        }) {
            HStack {
                Image(systemName: "book.fill")
                    .foregroundColor(.blue)
                Text("Browse Articles to Take Notes")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
        }
        .padding()
    }
    
    private var notesList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                let fetchRequest = createFetchRequest()
                FetchRequestView(fetchRequest: fetchRequest) { (notes: FetchedResults<SleepNote>) in
                    if notes.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(notes) { note in
                            if isSelectionMode {
                                let isSelected = selectedNotes.contains(note)
                                NoteCard(note: note)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                                    )
                                    .overlay(
                                        Group {
                                            if isSelected {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.blue)
                                                    .padding(8)
                                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                                            }
                                        }
                                    )
                                    .onTapGesture {
                                        toggleSelection(note)
                                    }
                            } else {
                                NavigationLink(destination: LearnNoteDetailView(note: note)) {
                                    NoteCard(note: note)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: selectedView == .highlights ? "highlighter" : "note.text")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text(getEmptyStateTitle())
                .font(.headline)
            
            Text(getEmptyStateMessage())
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if selectedView == .articles {
                NavigationLink(destination: LearnArticleListView(category: .basics) { articleId in
                    createArticleNote(articleId: articleId)
                }) {
                    Text("Browse Articles")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            } else {
                Button(action: { showingNewNote = true }) {
                    Text("Create Note")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private func filterButton(for type: ViewType) -> some View {
        Button(action: { selectedView = type }) {
            Text(type.rawValue)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selectedView == type ? Color.blue : Color(.systemGray5))
                .foregroundColor(selectedView == type ? .white : .primary)
                .cornerRadius(8)
        }
    }
    
    private func createFetchRequest() -> NSFetchRequest<SleepNote> {
        let request = SleepNote.fetchRequest()
        
        var predicates = [selectedView.predicate]
        if !searchText.isEmpty {
            predicates.append(NSPredicate(
                format: "title CONTAINS[cd] %@ OR content CONTAINS[cd] %@",
                searchText, searchText
            ))
        }
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = createSortDescriptors()
        
        return request
    }
    
    private func createSortDescriptors() -> [NSSortDescriptor] {
        switch selectedSort {
        case .date:
            return [NSSortDescriptor(keyPath: \SleepNote.modifiedAt, ascending: false)]
        case .title:
            return [NSSortDescriptor(keyPath: \SleepNote.title, ascending: true)]
        case .category:
            return [
                NSSortDescriptor(keyPath: \SleepNote.category, ascending: true),
                NSSortDescriptor(keyPath: \SleepNote.modifiedAt, ascending: false)
            ]
        }
    }
    
    private func getEmptyStateTitle() -> String {
        switch selectedView {
        case .all:
            return "No Notes Yet"
        case .highlights:
            return "No Highlights Yet"
        case .articles:
            return "No Article Notes Yet"
        case .quickNotes:
            return "No Quick Notes Yet"
        }
    }
    
    private func getEmptyStateMessage() -> String {
        switch selectedView {
        case .all:
            return "Start taking notes to track your sleep insights"
        case .highlights:
            return "Highlight important passages while reading articles"
        case .articles:
            return "Take notes while reading sleep articles"
        case .quickNotes:
            return "Quickly capture thoughts and observations"
        }
    }
    
    private func toggleSelection(_ note: SleepNote) {
        if selectedNotes.contains(note) {
            selectedNotes.remove(note)
        } else {
            selectedNotes.insert(note)
        }
    }
    
    private func showingQuickNote() {
        let note = SleepNote(context: viewContext)
        note.id = UUID()
        note.category = "quick_note"
        note.createdAt = Date()
        note.modifiedAt = Date()
        note.title = "Quick Note - \(Date().formatted(date: .abbreviated, time: .shortened))"
        
        // Show the note detail view for editing
        let detailView = NavigationView {
            LearnNoteDetailView(note: note)
        }
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            let hostingController = UIHostingController(rootView: detailView)
            rootViewController.present(hostingController, animated: true)
        }
    }
    
    private func createArticleNote(articleId: NSManagedObjectID) {
        guard let article = viewContext.object(with: articleId) as? LearnArticle else { return }
        
        let note = SleepNote(context: viewContext)
        note.id = UUID()
        note.article = article
        note.createdAt = Date()
        note.modifiedAt = Date()
        note.title = "Notes: \(article.title ?? "")"
        
        do {
            try viewContext.save()
            showingArticleLinks = false
        } catch {
            print("Error creating article note: \(error)")
        }
    }
}

#Preview {
    NavigationView {
        LearnNoteBrowserView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}