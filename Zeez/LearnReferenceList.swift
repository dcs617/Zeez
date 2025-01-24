import SwiftUI
import CoreData

struct LearnReferenceList: View {
    let references: [ScientificReference]
    let collapsible: Bool
    
    @State private var isExpanded = false
    
    init(references: [ScientificReference], collapsible: Bool = true) {
        self.references = references
        self.collapsible = collapsible
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("References")
                    .font(.headline)
                
                Spacer()
                
                if collapsible {
                    Button(action: { withAnimation { isExpanded.toggle() }}) {
                        Label(
                            isExpanded ? "Show Less" : "Show All",
                            systemImage: isExpanded ? "chevron.up" : "chevron.down"
                        )
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
            }
            
            // References
            VStack(spacing: 12) {
                ForEach(displayedReferences) { reference in
                    ReferenceCard(reference: reference)
                }
            }
        }
    }
    
    private var displayedReferences: [ScientificReference] {
        if !collapsible || isExpanded {
            return references
        }
        return Array(references.prefix(2))
    }
}

struct LearnArticleReferenceSection: View {
    let article: LearnArticle
    
    private var references: [ScientificReference] {
        article.references?.allObjects as? [ScientificReference] ?? []
    }
    
    var body: some View {
        if !references.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Divider()
                LearnReferenceList(references: references)
            }
        }
    }
}

struct LearnReferenceCounter: View {
    let count: Int
    
    var body: some View {
        if count > 0 {
            HStack(spacing: 4) {
                Image(systemName: "doc.text")
                    .font(.caption)
                Text("\(count)")
                    .font(.caption)
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let reference1 = ScientificReference(context: context)
    reference1.title = "First Reference"
    reference1.authors = "Author One"
    reference1.year = 2024
    
    let reference2 = ScientificReference(context: context)
    reference2.title = "Second Reference"
    reference2.authors = "Author Two"
    reference2.year = 2023
    
    return VStack(spacing: 20) {
        LearnReferenceList(references: [reference1, reference2])
        LearnReferenceCounter(count: 2)
    }
    .padding()
    .environment(\.managedObjectContext, context)
}