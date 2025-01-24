import SwiftUI
import CoreData

struct LearnHighlightableText: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var highlightManager: LearnHighlightManager
    
    let text: String
    let articleId: NSManagedObjectID
    @State private var showingColorPicker = false
    @State private var showingNoteOptions = false
    @State private var colorPickerPosition: CGPoint = .zero
    @State private var selectedText: String = ""
    @State private var showingNoteView = false
    @State private var currentHighlight: NoteHighlight?
    @State private var showingNotesList = false
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView {
                Text(highlightManager.buildAttributedString(
                    from: text,
                    highlights: highlightManager.getHighlights(for: articleId, context: viewContext)
                ))
                .textSelection(.enabled)
                .padding()
                .background(
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: ViewPositionKey.self,
                            value: geometry.frame(in: .global)
                        )
                    }
                )
                .onTapGesture {
                    showingColorPicker = false
                    showingNoteOptions = false
                }
                .onLongPressGesture {
                    handleLongPress()
                }
            }
            
            if showingColorPicker {
                colorPickerView
                    .position(x: colorPickerPosition.x, y: colorPickerPosition.y)
                    .transition(.scale)
            }
            
            if showingNoteOptions {
                noteOptionsView
                    .position(x: colorPickerPosition.x, y: colorPickerPosition.y)
                    .transition(.scale)
            }
        }
        .onPreferenceChange(ViewPositionKey.self) { bounds in
            self.colorPickerPosition = CGPoint(x: bounds.midX, y: bounds.minY + 50)
        }
        .sheet(isPresented: $showingNoteView) {
            if let highlight = currentHighlight,
               let article = highlight.article {
                NavigationView {
                    LearnNoteView(
                        article: article,
                        content: selectedText
                    )
                }
            }
        }
        .sheet(isPresented: $showingNotesList) {
            NotesSelectionView(
                onNoteSelected: mergeWithSelectedNote
            )
        }
        .contextMenu {
            contextMenuItems
        }
    }
    
    @ViewBuilder
    private var contextMenuItems: some View {
        if let selected = UIPasteboard.general.string,
           !selected.isEmpty {
            Group {
                if let highlight = getCurrentHighlight(text: selected) {
                    if highlight.note != nil {
                        Button(action: {
                            currentHighlight = highlight
                            selectedText = selected
                            showingNoteView = true
                        }) {
                            Label("View Note", systemImage: "doc.text")
                        }
                    }
                    
                    Button(action: {
                        currentHighlight = highlight
                        selectedText = selected
                        showingNoteOptions = true
                    }) {
                        Label("Note Options", systemImage: "square.and.pencil")
                    }
                    
                    Button(role: .destructive, action: {
                        removeHighlight(highlight)
                    }) {
                        Label("Remove Highlight", systemImage: "trash")
                    }
                } else {
                    Button(action: {
                        selectedText = selected
                        showingColorPicker = true
                    }) {
                        Label("Highlight", systemImage: "highlighter")
                    }
                    
                    Button(action: {
                        selectedText = selected
                        createHighlightWithNote()
                    }) {
                        Label("Highlight & Create Note", systemImage: "note.text")
                    }
                }
            }
        }
    }
    
    private var colorPickerView: some View {
        HStack(spacing: 12) {
            ForEach(LearnHighlightManager.HighlightColor.allCases, id: \.self) { color in
                colorButton(color)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(radius: 5)
        )
    }
    
    private var noteOptionsView: some View {
        VStack(spacing: 12) {
            Button(action: {
                createNoteFromHighlight()
                showingNoteOptions = false
            }) {
                Label("Create New Note", systemImage: "square.and.pencil")
                    .font(.headline)
            }
            
            Button(action: {
                showingNotesList = true
                showingNoteOptions = false
            }) {
                Label("Add to Existing Note", systemImage: "arrow.triangle.merge")
                    .font(.headline)
            }
            
            Button(action: { showingNoteOptions = false }) {
                Text("Cancel")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(radius: 5)
        )
    }
    
    private func colorButton(_ color: LearnHighlightManager.HighlightColor) -> some View {
        Circle()
            .fill(color.color)
            .frame(width: 30, height: 30)
            .overlay(
                Circle()
                    .stroke(Color.primary, lineWidth: highlightManager.selectedColor == color ? 2 : 0)
            )
            .onTapGesture {
                highlightManager.selectedColor = color
                createHighlight(createNote: false)
                showingColorPicker = false
            }
    }
    
    private func handleLongPress() {
        if let selected = UIPasteboard.general.string,
           let highlight = getCurrentHighlight(text: selected) {
            currentHighlight = highlight
            selectedText = selected
            showingNoteOptions = true
        } else {
            showingColorPicker = true
        }
    }
    
    private func getCurrentHighlight(text: String) -> NoteHighlight? {
        let highlights = highlightManager.getHighlights(for: articleId, context: viewContext)
        return highlights.first { $0.text == text }
    }
    
    private func createHighlight(createNote: Bool = false) {
        guard let range = text.range(of: selectedText) else { return }
        
        highlightManager.addHighlight(
            text: selectedText,
            range: range,
            articleId: articleId,
            context: viewContext,
            createNote: createNote
        )
    }
    
    private func createHighlightWithNote() {
        createHighlight(createNote: true)
        if let highlight = getCurrentHighlight(text: selectedText) {
            currentHighlight = highlight
            showingNoteView = true
        }
    }
    
    private func createNoteFromHighlight() {
        if let highlight = currentHighlight {
            highlightManager.createLinkedNote(for: highlight, in: viewContext)
            showingNoteView = true
        }
    }
    
    private func removeHighlight(_ highlight: NoteHighlight) {
        if let id = highlight.id {
            highlightManager.removeHighlight(
                id: id,
                context: viewContext,
                deleteLinkedNote: false
            )
        }
    }
    
    private func mergeWithSelectedNote(_ note: SleepNote) {
        guard let highlight = currentHighlight else { return }
        
        highlight.note = note
        note.modifiedAt = Date()
        
        let updatedContent = """
            \(note.content ?? "")
            
            Added Highlight:
            "\(highlight.text ?? "")"
            """
        
        note.content = updatedContent
        
        try? viewContext.save()
    }
}

struct ViewPositionKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

#Preview {
    LearnHighlightableText(
        text: "This is a sample text that can be highlighted.",
        articleId: NSManagedObjectID()
    )
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    .environmentObject(LearnHighlightManager())
}