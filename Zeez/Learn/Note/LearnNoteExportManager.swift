import SwiftUI
import PDFKit
import UniformTypeIdentifiers
import os.log

class LearnNoteExportManager {
    enum ExportFormat {
        case pdf
        case text
        case markdown
        case studyCards
        
        var fileExtension: String {
            switch self {
            case .pdf: return "pdf"
            case .text: return "txt"
            case .markdown: return "md"
            case .studyCards: return "json"
            }
        }
        
        var mimeType: String {
            switch self {
            case .pdf: return "application/pdf"
            case .text: return "text/plain"
            case .markdown: return "text/markdown"
            case .studyCards: return "application/json"
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: date)
    }
    
    // Create formatted content for a single note
    func formatNote(_ note: SleepNote, format: ExportFormat) -> String {
        var content = ""
        
        switch format {
        case .text:
            content += "Title: \(note.title ?? "")\n"
            content += "Category: \(note.category ?? "")\n"
            if let date = note.modifiedAt {
                content += "Date: \(date.formatted())\n"
            }
            content += "\n\(note.content ?? "")\n"
            if let article = note.article {
                content += "\nFrom Article: \(article.title ?? "")\n"
            }
            
        case .markdown:
            content += "# \(note.title ?? "")\n\n"
            content += "_Category: \(note.category ?? "")_\n"
            if let date = note.modifiedAt {
                content += "_Last Modified: \(date.formatted())_\n"
            }
            content += "\n\(note.content ?? "")\n"
            if let article = note.article {
                content += "\n**Referenced Article:** \(article.title ?? "")\n"
            }
            
        case .studyCards:
            // Create a study card format in JSON
            let card: [String: Any] = [
                "title": note.title ?? "",
                "content": note.content ?? "",
                "category": note.category ?? "",
                "date": note.modifiedAt?.ISO8601Format() ?? "",
                "article": note.article?.title ?? ""
            ]
            do {
                let data = try JSONSerialization.data(withJSONObject: card, options: .prettyPrinted)
                content = String(data: data, encoding: .utf8) ?? ""
            } catch {
                ZeezLogger.error(ZeezLogger.learning, "Error creating study card JSON", error: error)
            }
            
        case .pdf:
            // PDF content will be handled separately in createPDF()
            break
        }
        
        return content
    }
    
    // Create PDF data for a note
    func createPDF(for note: SleepNote) -> Data {
        let pdfMetaData = [
            kCGPDFContextCreator: "Zeez Sleep App",
            kCGPDFContextAuthor: "Zeez User",
            kCGPDFContextTitle: note.title ?? "Sleep Note"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4 size
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let data = renderer.pdfData { context in
            context.beginPage()
            
            let textFont = UIFont.systemFont(ofSize: 12)
            let titleFont = UIFont.boldSystemFont(ofSize: 18)
            let padding: CGFloat = 50
            var yPosition: CGFloat = padding
            
            // Title
            let titleAttributes = [
                NSAttributedString.Key.font: titleFont,
                NSAttributedString.Key.foregroundColor: UIColor.black
            ]
            let titleString = note.title ?? "Untitled Note"
            titleString.draw(at: CGPoint(x: padding, y: yPosition), withAttributes: titleAttributes)
            yPosition += 30
            
            // Metadata
            let metadataAttributes = [
                NSAttributedString.Key.font: UIFont.italicSystemFont(ofSize: 10),
                NSAttributedString.Key.foregroundColor: UIColor.darkGray
            ]
            let metadata = [
                "Category: \(note.category ?? "")",
                "Date: \(note.modifiedAt?.formatted() ?? "")",
                note.article != nil ? "From Article: \(note.article?.title ?? "")" : nil
            ].compactMap { $0 }
            
            for line in metadata {
                line.draw(at: CGPoint(x: padding, y: yPosition), withAttributes: metadataAttributes)
                yPosition += 20
            }
            yPosition += 10
            
            // Content
            let textAttributes = [
                NSAttributedString.Key.font: textFont,
                NSAttributedString.Key.foregroundColor: UIColor.black
            ]
            let content = note.content ?? ""
            
            let textRect = CGRect(x: padding, y: yPosition,
                                width: pageRect.width - (padding * 2),
                                height: pageRect.height - yPosition - padding)
            content.draw(in: textRect, withAttributes: textAttributes)
        }
        
        return data
    }
    
    // Create formatted content for multiple notes
    func formatNotes(_ notes: [SleepNote], format: ExportFormat) -> String {
        var content = ""
        
        switch format {
        case .text:
            content = notes.map { formatNote($0, format: .text) }
                .joined(separator: "\n---\n\n")
            
        case .markdown:
            content = notes.map { formatNote($0, format: .markdown) }
                .joined(separator: "\n---\n\n")
            
        case .studyCards:
            let cards = notes.compactMap { note -> [String: Any]? in
                [
                    "title": note.title ?? "",
                    "content": note.content ?? "",
                    "category": note.category ?? "",
                    "date": note.modifiedAt?.ISO8601Format() ?? "",
                    "article": note.article?.title ?? ""
                ]
            }
            do {
                let data = try JSONSerialization.data(withJSONObject: ["cards": cards], options: .prettyPrinted)
                content = String(data: data, encoding: .utf8) ?? ""
            } catch {
                ZeezLogger.error(ZeezLogger.learning, "Error creating study cards JSON", error: error)
            }
            
        case .pdf:
            // PDFs are handled separately
            break
        }
        
        return content
    }
    
    // Create a file URL for exported content
    func createFile(content: String, format: ExportFormat) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "zeez_notes_\(formatDate(Date())).\(format.fileExtension)"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            ZeezLogger.error(ZeezLogger.learning, "Error writing file", error: error)
            return nil
        }
    }
    
    // Create a PDF file for multiple notes
    func createPDFFile(notes: [SleepNote]) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "zeez_notes_\(formatDate(Date())).pdf"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        let pdfMetaData = [
            kCGPDFContextCreator: "Zeez Sleep App",
            kCGPDFContextAuthor: "Zeez User",
            kCGPDFContextTitle: "Zeez Sleep Notes"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4 size
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        do {
            try renderer.writePDF(to: fileURL) { context in
                for (index, note) in notes.enumerated() {
                    if index > 0 {
                        context.beginPage()
                    }
                    
                    // Draw note content using same logic as single note PDF
                    let textFont = UIFont.systemFont(ofSize: 12)
                    let titleFont = UIFont.boldSystemFont(ofSize: 18)
                    let padding: CGFloat = 50
                    var yPosition: CGFloat = padding
                    
                    // Title
                    let titleAttributes = [
                        NSAttributedString.Key.font: titleFont,
                        NSAttributedString.Key.foregroundColor: UIColor.black
                    ]
                    let titleString = note.title ?? "Untitled Note"
                    titleString.draw(at: CGPoint(x: padding, y: yPosition), withAttributes: titleAttributes)
                    yPosition += 30
                    
                    // Metadata
                    let metadataAttributes = [
                        NSAttributedString.Key.font: UIFont.italicSystemFont(ofSize: 10),
                        NSAttributedString.Key.foregroundColor: UIColor.darkGray
                    ]
                    let metadata = [
                        "Category: \(note.category ?? "")",
                        "Date: \(note.modifiedAt?.formatted() ?? "")",
                        note.article != nil ? "From Article: \(note.article?.title ?? "")" : nil
                    ].compactMap { $0 }
                    
                    for line in metadata {
                        line.draw(at: CGPoint(x: padding, y: yPosition), withAttributes: metadataAttributes)
                        yPosition += 20
                    }
                    yPosition += 10
                    
                    // Content
                    let textAttributes = [
                        NSAttributedString.Key.font: textFont,
                        NSAttributedString.Key.foregroundColor: UIColor.black
                    ]
                    let content = note.content ?? ""
                    
                    let textRect = CGRect(x: padding, y: yPosition,
                                        width: pageRect.width - (padding * 2),
                                        height: pageRect.height - yPosition - padding)
                    content.draw(in: textRect, withAttributes: textAttributes)
                }
            }
            return fileURL
        } catch {
            ZeezLogger.error(ZeezLogger.learning, "Error creating PDF file", error: error)
            return nil
        }
    }
}
