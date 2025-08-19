import SwiftUI
import CoreData
import os.log

struct LearnGlossaryTermDetailView: View {
    let term: GlossaryTerm
    @State private var showingReferences = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(term.term ?? "")
                        .font(.title2)
                        .fontWeight(.bold)
                        .accessibilityLabel("Term: \(term.term ?? "Unknown term")")
                        .accessibilityIdentifier("glossaryTermTitle")
                    
                    if let category = term.category {
                        Text(category)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .clipShape(Capsule())
                            .accessibilityLabel("Category: \(category)")
                            .accessibilityIdentifier("glossaryTermCategory")
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("glossaryTermHeader")
                
                if let definition = term.definition {
                    Text(definition)
                        .font(.body)
                        .foregroundColor(.primary)
                        .accessibilityLabel("Definition: \(definition)")
                        .accessibilityIdentifier("glossaryTermDefinition")
                }
                
                if let relatedTerms = term.relatedTerms as? Set<GlossaryTerm>, !relatedTerms.isEmpty {
                    relatedTermsSection(terms: Array(relatedTerms))
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func relatedTermsSection(terms: [GlossaryTerm]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Related Terms")
                .font(.headline)
                .accessibilityLabel("Related terms section")
                .accessibilityIdentifier("relatedTermsTitle")
            
            VStack(spacing: 8) {
                ForEach(terms) { term in
                    NavigationLink(destination: LearnGlossaryTermDetailView(term: term)) {
                        HStack {
                            Text(term.term ?? "")
                                .font(.subheadline)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .accessibilityLabel("Navigate to \(term.term ?? "related term")")
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .accessibilityLabel("Related term: \(term.term ?? "Unknown term")")
                    .accessibilityHint("Navigate to definition of \(term.term ?? "this term")")
                    .accessibilityIdentifier("relatedTerm_\(term.term?.replacingOccurrences(of: " ", with: "_") ?? "unknown")")
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("relatedTermsSection")
    }
}

#Preview {
    NavigationView {
        VStack {
            Text("No preview available")
                .foregroundColor(.secondary)
        }
    }
}
