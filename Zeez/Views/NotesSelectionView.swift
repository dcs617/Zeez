import SwiftUI
import CoreData
import os.log

struct NotesSelectionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    let onNoteSelected: (SleepNote) -> Void
    
    @State private var searchText = ""
    @State private var selectedCategory: LearnNoteView.NoteCategory?
    @State private var sortOrder: SortOrder = .modified
    @State private var showingArticlesOnly = false
    
    enum SortOrder: String, CaseIterable {
        case modified = "Modified"
        case created = "Created"
        case title = "Title"
        
        var icon: String {
            switch self {
            case .modified: return "clock"
            case .created: return "calendar"
            case .title: return "textformat"
            }
        }
    }
    
    @FetchRequest private var notes: FetchedResults<SleepNote>
    
    init(onNoteSelected: @escaping (SleepNote) -> Void) {
        self.onNoteSelected = onNoteSelected
        _notes = FetchRequest(
            entity: SleepNote.entity(),
            sortDescriptors: [NSSortDescriptor(keyPath: \SleepNote.modifiedAt, ascending: false)],
            predicate: nil
        )
    }
    
    private var filteredNotes: [SleepNote] {
        notes.filter { note in
            let matchesSearch = searchText.isEmpty ||
                (note.title?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (note.content?.localizedCaseInsensitiveContains(searchText) ?? false)
            
            let matchesCategory = selectedCategory == nil ||
                note.category == selectedCategory?.rawValue
            
            let matchesArticleFilter = !showingArticlesOnly || note.article != nil
            
            return matchesSearch && matchesCategory && matchesArticleFilter
        }
        .sorted { note1, note2 in
            switch sortOrder {
            case .modified:
                return note1.modifiedAt ?? Date() > note2.modifiedAt ?? Date()
            case .created:
                return note1.createdAt ?? Date() > note2.createdAt ?? Date()
            case .title:
                return note1.title?.localizedCompare(note2.title ?? "") == .orderedAscending
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            searchBar
            filterBar
            
            if filteredNotes.isEmpty {
                emptyStateView
            } else {
                notesList
            }
        }
        .navigationTitle("Select Note")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Cancel") { dismiss() }
                    .accessibilityLabel("Cancel note selection")
                    .accessibilityIdentifier("cancelNoteSelection")
            }
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .accessibilityHidden(true)
            
            TextField("Search notes", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .accessibilityLabel("Search notes")
                .accessibilityHint("Search by title or content")
                .accessibilityIdentifier("notesSearchField")
        }
        .padding()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("searchBar")
    }
    
    private var filterBar: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    categoryButton(nil)
                    
                    ForEach(LearnNoteView.NoteCategory.allCases, id: \.self) { category in
                        categoryButton(category)
                    }
                }
                .padding(.horizontal)
            }
            
            HStack {
                Toggle("Article Notes Only", isOn: $showingArticlesOnly)
                    .toggleStyle(.button)
                    .tint(.blue)
                    .accessibilityLabel("Show article notes only")
                    .accessibilityHint("Toggle to filter only notes linked to articles")
                    .accessibilityIdentifier("articleNotesToggle")
                
                Spacer()
                
                Menu {
                    ForEach(SortOrder.allCases, id: \.self) { order in
                        Button {
                            sortOrder = order
                        } label: {
                            Label(order.rawValue, systemImage: order.icon)
                                .foregroundColor(sortOrder == order ? .blue : .primary)
                        }
                        .accessibilityLabel("Sort by \(order.rawValue)")
                        .accessibilityIdentifier("sortOption_\(order.rawValue.lowercased())")
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
                .menuStyle(.button)
                .accessibilityLabel("Sort options")
                .accessibilityHint("Change how notes are sorted")
                .accessibilityIdentifier("sortMenu")
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.gray)
                .accessibilityHidden(true)
            
            if !searchText.isEmpty {
                Text("No matching notes")
                    .font(.headline)
                Text("Try adjusting your search or filters")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else if showingArticlesOnly {
                Text("No article notes")
                    .font(.headline)
                Text("Try viewing all notes")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("No notes found")
                    .font(.headline)
                Text("Try adjusting your filters")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(getEmptyStateMessage())
        .accessibilityIdentifier("notesEmptyState")
    }
    
    private func getEmptyStateMessage() -> String {
        if !searchText.isEmpty {
            return "No matching notes. Try adjusting your search or filters"
        } else if showingArticlesOnly {
            return "No article notes. Try viewing all notes"
        } else {
            return "No notes found. Try adjusting your filters"
        }
    }
    
    private var notesList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredNotes) { note in
                    Button {
                        onNoteSelected(note)
                        dismiss()
                    } label: {
                        noteCard(note)
                    }
                    .accessibilityLabel("Select note: \(note.title ?? "Untitled Note")")
                    .accessibilityHint("Tap to select this note")
                    .accessibilityIdentifier("noteCard_\(note.title?.replacingOccurrences(of: " ", with: "").lowercased() ?? "untitled")")
                }
            }
            .padding()
        }
    }
    
    private func categoryButton(_ category: LearnNoteView.NoteCategory?) -> some View {
        Button {
            selectedCategory = category
        } label: {
            HStack {
                if let category = category {
                    Image(systemName: category.icon)
                        .foregroundColor(category.color)
                        .accessibilityHidden(true)
                }
                Text(category?.rawValue ?? "All")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(selectedCategory == category ? Color.blue : Color(.systemGray5))
            .foregroundColor(selectedCategory == category ? .white : .primary)
            .cornerRadius(8)
        }
        .accessibilityLabel("Filter by \(category?.rawValue ?? "all categories")")
        .accessibilityHint(selectedCategory == category ? "Currently selected" : "Tap to filter notes")
        .accessibilityIdentifier("categoryFilter_\(category?.rawValue.lowercased().replacingOccurrences(of: " ", with: "") ?? "all")")
    }
    
    private func noteCard(_ note: SleepNote) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let category = note.category,
                   let noteCategory = LearnNoteView.NoteCategory(rawValue: category) {
                    Image(systemName: noteCategory.icon)
                        .foregroundColor(noteCategory.color)
                        .accessibilityLabel("Category: \(noteCategory.rawValue)")
                        .accessibilityIdentifier("noteCategoryIcon")
                }
                
                Text(note.title ?? "Untitled Note")
                    .font(.headline)
                
                Spacer()
                
                if note.article != nil {
                    Image(systemName: "book.fill")
                        .foregroundColor(.blue)
                        .accessibilityLabel("Linked to article")
                        .accessibilityIdentifier("noteArticleIcon")
                }
            }
            
            if let content = note.content {
                Text(content)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .accessibilityLabel("Note preview: \(content)")
                    .accessibilityIdentifier("notePreview")
            }
            
            HStack {
                if let date = note.modifiedAt {
                    Label(date.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .accessibilityLabel("Modified \(date.formatted(date: .abbreviated, time: .shortened))")
                        .accessibilityIdentifier("noteModifiedDate")
                }
                
                if let article = note.article {
                    Spacer()
                    Text(article.title ?? "")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .accessibilityLabel("From article: \(article.title ?? "")")
                        .accessibilityIdentifier("noteArticleTitle")
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("noteCardContent")
    }
}

#Preview {
    NavigationView {
        NotesSelectionView { note in
            ZeezLogger.debug(ZeezLogger.ui, "Selected note: \(note.title ?? "")")
        }
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
