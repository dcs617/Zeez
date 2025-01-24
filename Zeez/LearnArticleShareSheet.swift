import SwiftUI
import CoreData

struct LearnArticleShareSheet: View {
    @Environment(\.dismiss) private var dismiss
    let article: LearnArticle
    @State private var selectedFormat: ExportFormat = .text
    @State private var includeHighlights = true
    @State private var includeNotes = true
    @State private var exportingURL: URL?
    @State private var showingExport = false
    @State private var showingError = false
    
    enum ExportFormat: String, CaseIterable {
        case text = "Plain Text"
        case markdown = "Markdown"
        case pdf = "PDF Document"
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Export Format") {
                    Picker("Format", selection: $selectedFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("Include") {
                    Toggle("Highlights", isOn: $includeHighlights)
                    Toggle("Your Notes", isOn: $includeNotes)
                }
                
                Section {
                    Button(action: shareArticle) {
                        Label("Export Article", systemImage: "square.and.arrow.up")
                    }
                }
                
                Section("Preview") {
                    ScrollView {
                        VStack(alignment: .leading) {
                            Text(getPreviewContent())
                                .font(.caption)
                                .textSelection(.enabled)
                        }
                    }
                    .frame(maxHeight: 200)
                }
            }
            .navigationTitle("Share Article")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showingExport) {
                if let url = exportingURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .alert("Export Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("There was an error exporting the article. Please try again.")
            }
        }
    }
    
    private func shareArticle() {
        let tempURL: URL
        do {
            switch selectedFormat {
            case .text:
                tempURL = try createTextFile()
            case .markdown:
                tempURL = try createMarkdownFile()
            case .pdf:
                tempURL = try createPDFFile()
            }
            exportingURL = tempURL
            showingExport = true
        } catch {
            showingError = true
        }
    }
    
    private func createTextFile() throws -> URL {
        let content = getTextContent()
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("article.txt")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
    
    private func createMarkdownFile() throws -> URL {
        let content = getMarkdownContent()
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("article.md")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
    
    private func createPDFFile() throws -> URL {
        let renderer = PDFRenderer(article: article, includeHighlights: includeHighlights, includeNotes: includeNotes)
        let pdfData = renderer.createPDF()
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("article.pdf")
        try pdfData.write(to: fileURL)
        return fileURL
    }
    
    private func getPreviewContent() -> String {
        switch selectedFormat {
        case .text:
            return getTextContent()
        case .markdown:
            return getMarkdownContent()
        case .pdf:
            return """
                PDF Export will include:
                - Full article content
                \(includeHighlights ? "- Your highlights\n" : "")
                \(includeNotes ? "- Your notes\n" : "")
                - References and citations
                """
        }
    }
    
    private func getTextContent() -> String {
        var content = """
            \(article.title ?? "")
            Reading Time: \(article.readTimeMinutes) minutes
            
            \(article.content ?? "")
            
            """
        
        if includeHighlights, let highlights = article.highlights as? Set<NoteHighlight>, !highlights.isEmpty {
            content += "\nHighlights:\n"
            highlights.forEach { highlight in
                content += "- \(highlight.text ?? "")\n"
            }
        }
        
        if includeNotes, let notes = article.notes as? Set<SleepNote>, !notes.isEmpty {
            content += "\nNotes:\n"
            notes.forEach { note in
                content += """
                    - \(note.title ?? "")
                      \(note.content ?? "")
                    
                    """
            }
        }
        
        if let references = article.references as? Set<ScientificReference>, !references.isEmpty {
            content += "\nReferences:\n"
            references.forEach { reference in
                if let citation = reference.citation {
                    content += "- \(citation)\n"
                }
            }
        }
        
        return content
    }
    
    private func getMarkdownContent() -> String {
        var content = """
            # \(article.title ?? "")
            _Reading Time: \(article.readTimeMinutes) minutes_
            
            \(article.content ?? "")
            
            """
        
        if includeHighlights, let highlights = article.highlights as? Set<NoteHighlight>, !highlights.isEmpty {
            content += "\n## Highlights\n\n"
            highlights.forEach { highlight in
                content += "> \(highlight.text ?? "")\n\n"
            }
        }
        
        if includeNotes, let notes = article.notes as? Set<SleepNote>, !notes.isEmpty {
            content += "\n## Notes\n\n"
            notes.forEach { note in
                content += """
                    ### \(note.title ?? "")
                    \(note.content ?? "")
                    
                    """
            }
        }
        
        if let references = article.references as? Set<ScientificReference>, !references.isEmpty {
            content += "\n## References\n\n"
            references.forEach { reference in
                if let citation = reference.citation {
                    content += "* \(citation)\n"
                }
            }
        }
        
        return content
    }
}

struct PDFRenderer {
    let article: LearnArticle
    let includeHighlights: Bool
    let includeNotes: Bool
    
    func createPDF() -> Data {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextCreator: "Zeez Sleep App",
            kCGPDFContextTitle: article.title ?? "Article"
        ] as [String: Any]
        
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        return renderer.pdfData { context in
            var y: CGFloat = 50
            let padding: CGFloat = 50
            let contentWidth = pageRect.width - (padding * 2)
            
            // Title
            y = drawText(article.title ?? "", at: y, font: .boldSystemFont(ofSize: 24), padding: padding, pageRect: pageRect, context: context)
            y += 20
            
            // Reading time
            y = drawText("Reading Time: \(article.readTimeMinutes) minutes", at: y, font: .italicSystemFont(ofSize: 12), padding: padding, pageRect: pageRect, context: context)
            y += 30
            
            // Content
            y = drawText(article.content ?? "", at: y, font: .systemFont(ofSize: 12), padding: padding, pageRect: pageRect, context: context)
            y += 30
            
            // Start a new page for highlights and notes
            if includeHighlights || includeNotes {
                context.beginPage()
                y = 50
            }
            
            if includeHighlights, let highlights = article.highlights as? Set<NoteHighlight>, !highlights.isEmpty {
                y = drawText("Highlights", at: y, font: .boldSystemFont(ofSize: 16), padding: padding, pageRect: pageRect, context: context)
                y += 20
                
                for highlight in highlights {
                    y = drawText("• \(highlight.text ?? "")", at: y, font: .systemFont(ofSize: 12), padding: padding + 20, pageRect: pageRect, context: context)
                    y += 10
                }
                y += 20
            }
            
            if includeNotes, let notes = article.notes as? Set<SleepNote>, !notes.isEmpty {
                if y > pageRect.height - 200 {
                    context.beginPage()
                    y = 50
                }
                
                y = drawText("Notes", at: y, font: .boldSystemFont(ofSize: 16), padding: padding, pageRect: pageRect, context: context)
                y += 20
                
                for note in notes {
                    y = drawText(note.title ?? "", at: y, font: .boldSystemFont(ofSize: 12), padding: padding + 20, pageRect: pageRect, context: context)
                    y += 10
                    y = drawText(note.content ?? "", at: y, font: .systemFont(ofSize: 12), padding: padding + 20, pageRect: pageRect, context: context)
                    y += 20
                }
            }
            
            // Start a new page for references
            if let references = article.references as? Set<ScientificReference>, !references.isEmpty {
                context.beginPage()
                y = 50
                
                y = drawText("References", at: y, font: .boldSystemFont(ofSize: 16), padding: padding, pageRect: pageRect, context: context)
                y += 20
                
                for reference in references {
                    if let citation = reference.citation {
                        y = drawText("• \(citation)", at: y, font: .systemFont(ofSize: 12), padding: padding + 20, pageRect: pageRect, context: context)
                        y += 20
                    }
                }
            }
        }
    }
    
    private func drawText(_ text: String, at y: CGFloat, font: UIFont, padding: CGFloat, pageRect: CGRect, context: UIGraphicsPDFRendererContext) -> CGFloat {
        let contentWidth = pageRect.width - (padding * 2)
        let textAttributes = [NSAttributedString.Key.font: font]
        let textRect = CGRect(x: padding, y: y, width: contentWidth, height: 9999)
        let textSize = text.boundingRect(with: CGSize(width: contentWidth, height: 9999),
                                       options: [.usesLineFragmentOrigin],
                                       attributes: textAttributes,
                                       context: nil)
        
        // Check if we need a new page
        if y + textSize.height > pageRect.height - padding {
            context.beginPage()
            text.draw(in: CGRect(x: padding, y: padding, width: contentWidth, height: textSize.height),
                     withAttributes: textAttributes)
            return padding + textSize.height
        }
        
        text.draw(in: textRect, withAttributes: textAttributes)
        return y + textSize.height
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let article = LearnArticle(context: context)
    article.title = "Sample Article"
    article.content = "This is a sample article content."
    return LearnArticleShareSheet(article: article)
}
