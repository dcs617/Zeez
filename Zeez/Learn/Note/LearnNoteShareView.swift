import SwiftUI
import UniformTypeIdentifiers
import os.log

struct LearnNoteShareView: View {
    @Environment(\.dismiss) private var dismiss
    let notes: [SleepNote]
    let exportManager = LearnNoteExportManager()
    
    @State private var selectedFormat: LearnNoteExportManager.ExportFormat = .pdf
    @State private var isExporting = false
    @State private var exportURL: URL?
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            List {
                Section("Export Format") {
                    Picker("Format", selection: $selectedFormat) {
                        Text("PDF Document").tag(LearnNoteExportManager.ExportFormat.pdf)
                        Text("Text File").tag(LearnNoteExportManager.ExportFormat.text)
                        Text("Markdown").tag(LearnNoteExportManager.ExportFormat.markdown)
                        Text("Study Cards").tag(LearnNoteExportManager.ExportFormat.studyCards)
                    }
                    .pickerStyle(.menu)
                    .accessibilityLabel("Export format")
                    .accessibilityHint("Choose the format for exporting your notes")
                    .accessibilityIdentifier("exportFormatPicker")
                }
                
                Section {
                    Button(action: exportNotes) {
                        Label("Export Notes", systemImage: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Export notes")
                    .accessibilityHint("Export \(notes.count) notes in the selected format")
                    .accessibilityIdentifier("exportNotesButton")
                }
                
                Section("Preview") {
                    previewContent
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("Export preview")
                        .accessibilityHint("Preview of how the exported notes will appear")
                        .accessibilityIdentifier("exportPreview")
                }
                
                if notes.count == 1 {
                    Section("Quick Share") {
                        ShareLink(
                            item: notes.first?.content ?? "",
                            preview: SharePreview(
                                notes.first?.title ?? "Note",
                                image: Image(systemName: "note.text")
                            )
                        )
                        .accessibilityLabel("Quick share note")
                        .accessibilityHint("Share note content directly with other apps")
                        .accessibilityIdentifier("quickShareLink")
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Note sharing options")
            .accessibilityHint("Choose how to export and share your notes")
            .accessibilityIdentifier("shareOptionsList")
            .navigationTitle("Share Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                    .accessibilityLabel("Done")
                    .accessibilityHint("Close note sharing view")
                    .accessibilityIdentifier("shareViewDoneButton")
                }
            }
            .sheet(isPresented: $isExporting) {
                if let url = exportURL {
                    ShareSheet(activityItems: [url])
                        .accessibilityLabel("Share exported notes")
                        .accessibilityHint("Choose how to share your exported notes file")
                        .accessibilityIdentifier("shareSheet")
                }
            }
            .alert("Export Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var previewContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if selectedFormat == .pdf {
                Text("PDF will include:")
                ForEach(notes) { note in
                    Text("• \(note.title ?? "")")
                        .font(.caption)
                        .accessibilityLabel("Note to export: \(note.title ?? "Untitled")")
                        .accessibilityIdentifier("exportNote_\(note.title?.replacingOccurrences(of: " ", with: "_") ?? "untitled")")
                }
            } else {
                ScrollView {
                    Text(exportManager.formatNotes(notes, format: selectedFormat))
                        .font(.caption)
                        .textSelection(.enabled)
                        .accessibilityLabel("Preview text: \(exportManager.formatNotes(notes, format: selectedFormat).prefix(100))...")
                        .accessibilityIdentifier("previewText")
                }
                .frame(maxHeight: 200)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Export preview")
                .accessibilityHint("Scrollable preview of exported content")
                .accessibilityIdentifier("previewScrollView")
            }
        }
    }
    
    private func exportNotes() {
        switch selectedFormat {
        case .pdf:
            if let url = exportManager.createPDFFile(notes: notes) {
                exportURL = url
                isExporting = true
            }
        case .text, .markdown, .studyCards:
            let content = exportManager.formatNotes(notes, format: selectedFormat)
            if let url = exportManager.createFile(content: content, format: selectedFormat) {
                exportURL = url
                isExporting = true
            }
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let note = SleepNote(context: context)
    note.title = "Sample Note"
    note.content = "This is a sample note content"
    return LearnNoteShareView(notes: [note])
}
