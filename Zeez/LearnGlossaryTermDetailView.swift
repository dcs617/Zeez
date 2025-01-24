import SwiftUI
import CoreData

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
                    
                    if let category = term.category {
                        Text(category)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .clipShape(Capsule())
                    }
                }
                
                if let definition = term.definition {
                    Text(definition)
                        .font(.body)
                        .foregroundColor(.primary)
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
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                }
            }
        }
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