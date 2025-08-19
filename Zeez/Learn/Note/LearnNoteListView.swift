import SwiftUI
import CoreData
import os.log

struct LearnNoteListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest<SleepNote>(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \SleepNote.modifiedAt, ascending: false)
        ],
        animation: .default
    ) private var notes
    
    @State private var showingNewNote = false
    @State private var searchText = ""
    @State private var selectedCategory: LearnNoteView.NoteCategory?
    
    private var notesArray: [SleepNote] {
        Array(notes)
    }
    
    private var filteredNotes: [SleepNote] {
        notesArray.filter { note in
            let matchesSearch = searchText.isEmpty ||
                (note.title?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (note.content?.localizedCaseInsensitiveContains(searchText) ?? false)
            
            let matchesCategory = selectedCategory == nil ||
                note.category == selectedCategory?.rawValue
            
            return matchesSearch && matchesCategory
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            searchBar
            
            if !notesArray.isEmpty {
                categoryFilter
            }
            
            if filteredNotes.isEmpty {
                emptyState
            } else {
                noteList
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Notes list")
        .accessibilityHint("Browse and search through your sleep learning notes")
        .accessibilityIdentifier("notesListView")
        .navigationTitle("Notes")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingNewNote = true }) {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .sheet(isPresented: $showingNewNote) {
            LearnNoteView(article: nil)
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
    
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                categoryPill(nil)
                
                ForEach(LearnNoteView.NoteCategory.allCases, id: \.self) { category in
                    categoryPill(category)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
    
    private func categoryPill(_ category: LearnNoteView.NoteCategory?) -> some View {
        Button(action: { selectedCategory = category }) {
            HStack {
                if let category = category {
                    Image(systemName: category.icon)
                    Text(category.rawValue)
                } else {
                    Text("All")
                }
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(selectedCategory == category ? Color.blue : Color(.systemGray5))
            .foregroundColor(selectedCategory == category ? .white : .primary)
            .cornerRadius(16)
        }
    }
    
    private var noteList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredNotes) { note in
                    NavigationLink(destination: LearnNoteDetailView(note: note)) {
                        NoteSummaryCard(note: note)
                    }
                }
            }
            .padding()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "note.text")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text(getEmptyStateTitle())
                .font(.headline)
            
            Text(getEmptyStateMessage())
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: { showingNewNote = true }) {
                Text("Create Note")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func getEmptyStateTitle() -> String {
        if notesArray.isEmpty {
            return "No Notes Yet"
        } else if !searchText.isEmpty {
            return "No Matching Notes"
        } else {
            return "No Notes Found"
        }
    }
    
    private func getEmptyStateMessage() -> String {
        if notesArray.isEmpty {
            return "Start taking notes to track your sleep insights"
        } else if !searchText.isEmpty {
            return "Try adjusting your search terms"
        } else {
            return "Try changing your filters"
        }
    }
}

struct NoteSummaryCard: View {
    let note: SleepNote
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let category = note.category,
                   let noteCategory = LearnNoteView.NoteCategory(rawValue: category) {
                    Image(systemName: noteCategory.icon)
                        .foregroundColor(noteCategory.color)
                }
                
                Text(note.title ?? "")
                    .font(.headline)
                
                Spacer()
                
                if let date = note.modifiedAt {
                    Text(date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let content = note.content {
                Text(content)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            if let article = note.article {
                Label(article.title ?? "", systemImage: "book")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    NavigationView {
        LearnNoteListView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
