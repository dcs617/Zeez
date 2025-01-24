import SwiftUI
import UniformTypeIdentifiers

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
                }
                
                Section {
                    Button(action: exportNotes) {
                        Label("Export Notes", systemImage: "square.and.arrow.up")
                    }
                }
                
                Section("Preview") {
                    previewContent
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
                    }
                }
            }
            .navigationTitle("Share Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $isExporting) {
                if let url = exportURL {
                    ShareSheet(activityItems: [url])
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
                }
            } else {
                ScrollView {
                    Text(exportManager.formatNotes(notes, format: selectedFormat))
                        .font(.caption)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 200)
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
