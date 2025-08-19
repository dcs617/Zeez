import SwiftUI
import CoreData
import os.log

struct LearnNoteLinker: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    let currentNote: SleepNote
    
    @FetchRequest<SleepNote>(
        entity: SleepNote.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \SleepNote.modifiedAt, ascending: false)],
        animation: .default
    ) private var allNotes
    
    @State private var searchText = ""
    @State private var selectedNotes: Set<NSManagedObjectID> = []
    
    var filteredNotes: [SleepNote] {
        allNotes.filter { note in
            if note.objectID == currentNote.objectID { return false }
            
            if searchText.isEmpty { return true }
            
            return note.title?.localizedCaseInsensitiveContains(searchText) == true ||
                   note.content?.localizedCaseInsensitiveContains(searchText) == true
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                searchBar
                
                List(filteredNotes, selection: $selectedNotes) { note in
                    noteRow(note)
                }
                .environment(\.editMode, .constant(.active))
            }
            .navigationTitle("Link Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        saveLinks()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
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
        .background(Color(.systemGray6))
    }
    
    private func noteRow(_ note: SleepNote) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.title ?? "")
                .font(.headline)
            
            if let content = note.content {
                Text(content)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }
    
    private func saveLinks() {
        let selectedNoteObjects = selectedNotes.compactMap { id in
            try? viewContext.existingObject(with: id) as? SleepNote
        }
        
        // Create a set for the current note's linked notes
        let currentLinkedNotes = currentNote.linkedNotes as? Set<SleepNote> ?? Set()
        
        // Create a new set with the selected notes
        let newLinkedNotes = Set(selectedNoteObjects)
        
        // Find notes to unlink (in current but not in new)
        let notesToUnlink = currentLinkedNotes.subtracting(newLinkedNotes)
        
        // Find notes to link (in new but not in current)
        let notesToLink = newLinkedNotes.subtracting(currentLinkedNotes)
        
        // Update bidirectional relationships
        for note in notesToUnlink {
            var noteLinkedNotes = note.linkedNotes as? Set<SleepNote> ?? Set()
            noteLinkedNotes.remove(currentNote)
            note.linkedNotes = noteLinkedNotes as NSSet
        }
        
        for note in notesToLink {
            var noteLinkedNotes = note.linkedNotes as? Set<SleepNote> ?? Set()
            noteLinkedNotes.insert(currentNote)
            note.linkedNotes = noteLinkedNotes as NSSet
        }
        
        // Update the current note's linked notes
        currentNote.linkedNotes = newLinkedNotes as NSSet
        
        do {
            try viewContext.save()
        } catch {
            ZeezLogger.error(ZeezLogger.learning, "Error saving note links", error: error)
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let note = SleepNote(context: context)
    note.title = "Sample Note"
    return LearnNoteLinker(currentNote: note)
        .environment(\.managedObjectContext, context)
}
