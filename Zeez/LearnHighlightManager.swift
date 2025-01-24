import SwiftUI
import CoreData

class LearnHighlightManager: ObservableObject {
    @Published var highlightedRanges: [UUID: [Range<String.Index>]] = [:]
    @Published var selectedColor: HighlightColor = .yellow
    @Published var linkedNotes: [UUID: SleepNote] = [:]
    
    enum HighlightColor: String, CaseIterable {
        case yellow = "yellow"
        case green = "green"
        case blue = "blue"
        case pink = "pink"
        
        var color: Color {
            switch self {
            case .yellow: return Color.yellow.opacity(0.3)
            case .green: return Color.green.opacity(0.3)
            case .blue: return Color.blue.opacity(0.3)
            case .pink: return Color.pink.opacity(0.3)
            }
        }
        
        var displayName: String {
            rawValue.capitalized
        }
        
        var suggestedCategory: String {
            switch self {
            case .yellow: return "general"
            case .green: return "insight"
            case .blue: return "summary"
            case .pink: return "question"
            }
        }
    }
    
    func addHighlight(text: String, range: Range<String.Index>, articleId: NSManagedObjectID, context: NSManagedObjectContext, createNote: Bool = false) {
        let highlight = NoteHighlight(context: context)
        highlight.id = UUID()
        highlight.text = String(text[range])
        highlight.color = selectedColor.rawValue
        highlight.createdAt = Date()
        
        if let article = try? context.existingObject(with: articleId) as? LearnArticle {
            highlight.article = article
            
            if createNote {
                createLinkedNote(for: highlight, in: context)
            }
        }
        
        do {
            try context.save()
            highlightedRanges[highlight.id ?? UUID(), default: []].append(range)
        } catch {
            print("Error saving highlight: \(error)")
        }
    }
    
    func createLinkedNote(for highlight: NoteHighlight, in context: NSManagedObjectContext) {
        let note = SleepNote(context: context)
        note.id = UUID()
        note.title = generateNoteTitle(from: highlight.text ?? "")
        note.content = """
            Highlighted Text:
            "\(highlight.text ?? "")"
            
            Notes:
            
            """
        note.category = selectedColor.suggestedCategory
        note.createdAt = Date()
        note.modifiedAt = Date()
        note.article = highlight.article
        
        // Link note and highlight
        highlight.note = note
        
        do {
            try context.save()
            if let id = highlight.id {
                linkedNotes[id] = note
            }
        } catch {
            print("Error creating linked note: \(error)")
        }
    }
    
    private func generateNoteTitle(from text: String) -> String {
        let words = text.split(separator: " ")
        let titleWords = words.prefix(5).joined(separator: " ")
        return "\(titleWords)..."
    }
    
    func removeHighlight(id: UUID, context: NSManagedObjectContext, deleteLinkedNote: Bool = false) {
        let fetchRequest: NSFetchRequest<NoteHighlight> = NoteHighlight.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        do {
            let highlights = try context.fetch(fetchRequest)
            if let highlight = highlights.first {
                if deleteLinkedNote, let note = highlight.note {
                    context.delete(note)
                }
                context.delete(highlight)
                try context.save()
                highlightedRanges.removeValue(forKey: id)
                linkedNotes.removeValue(forKey: id)
            }
        } catch {
            print("Error removing highlight: \(error)")
        }
    }
    
    func getHighlights(for articleId: NSManagedObjectID, context: NSManagedObjectContext) -> [NoteHighlight] {
        let fetchRequest: NSFetchRequest<NoteHighlight> = NoteHighlight.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "article == %@", articleId)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \NoteHighlight.createdAt, ascending: true)]
        
        do {
            let highlights = try context.fetch(fetchRequest)
            for highlight in highlights {
                if let id = highlight.id, let note = highlight.note {
                    linkedNotes[id] = note
                }
            }
            return highlights
        } catch {
            print("Error fetching highlights: \(error)")
            return []
        }
    }
    
    func updateNoteContent(_ content: String, for highlightId: UUID, context: NSManagedObjectContext) {
        guard let note = linkedNotes[highlightId] else { return }
        
        note.content = content
        note.modifiedAt = Date()
        
        do {
            try context.save()
        } catch {
            print("Error updating note content: \(error)")
        }
    }
    
    func mergeNotes(for highlights: [NoteHighlight], context: NSManagedObjectContext) {
        guard !highlights.isEmpty else { return }
        
        let mergedNote = SleepNote(context: context)
        mergedNote.id = UUID()
        mergedNote.title = "Merged Notes - \(Date().formatted())"
        mergedNote.createdAt = Date()
        mergedNote.modifiedAt = Date()
        mergedNote.category = "merged"
        mergedNote.article = highlights.first?.article
        
        let content = highlights.compactMap { highlight -> String? in
            guard let text = highlight.text else { return nil }
            return """
                Highlight:
                "\(text)"
                
                Notes:
                \(highlight.note?.content ?? "")
                
                ---
                
                """
        }.joined(separator: "\n")
        
        mergedNote.content = content
        
        for highlight in highlights {
            highlight.note = mergedNote
        }
        
        do {
            try context.save()
            for highlight in highlights {
                if let id = highlight.id {
                    linkedNotes[id] = mergedNote
                }
            }
        } catch {
            print("Error merging notes: \(error)")
        }
    }
    
    func buildAttributedString(from text: String, highlights: [NoteHighlight]) -> AttributedString {
        var attributedString = AttributedString(text)
        
        for highlight in highlights {
            guard let highlightText = highlight.text,
                  let range = text.range(of: highlightText),
                  let color = HighlightColor(rawValue: highlight.color ?? "yellow") else {
                continue
            }
            
            let nsRange = NSRange(range, in: text)
            let attStringRange = Range(nsRange, in: attributedString)!
            
            attributedString[attStringRange].backgroundColor = color.color
            if highlight.note != nil {
                attributedString[attStringRange].underlineStyle = .single
            }
        }
        
        return attributedString
    }
}
