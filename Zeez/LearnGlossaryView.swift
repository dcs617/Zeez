import SwiftUI
import CoreData

struct LearnGlossaryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var searchText = ""
    @State private var selectedCategory: String?
    
    @FetchRequest<GlossaryTerm>(
        sortDescriptors: [NSSortDescriptor(keyPath: \GlossaryTerm.term, ascending: true)],
        animation: .default
    ) private var terms
    
    private var termsArray: [GlossaryTerm] {
        Array(terms)
    }
    
    private var categories: [String] {
        Array(Set(termsArray.compactMap { $0.category })).sorted()
    }
    
    private var filteredTerms: [GlossaryTerm] {
        termsArray.filter { term in
            let matchesSearch = searchText.isEmpty ||
                (term.term?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (term.definition?.localizedCaseInsensitiveContains(searchText) ?? false)
            
            let matchesCategory = selectedCategory == nil ||
                term.category == selectedCategory
            
            return matchesSearch && matchesCategory
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            searchBar
            
            categorySelector
            
            List {
                ForEach(filteredTerms) { term in
                    NavigationLink(destination: LearnGlossaryTermDetailView(term: term)) {
                        GlossaryTermRow(term: term)
                    }
                }
            }
        }
        .navigationTitle("Sleep Glossary")
        .navigationBarTitleDisplayMode(.large)
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search terms", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .padding()
    }
    
    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                categoryButton(nil)
                
                ForEach(categories, id: \.self) { category in
                    categoryButton(category)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
    
    private func categoryButton(_ category: String?) -> some View {
        Button(action: { selectedCategory = category }) {
            Text(category ?? "All")
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(selectedCategory == category ? Color.blue : Color(.systemGray5))
                )
                .foregroundColor(selectedCategory == category ? .white : .primary)
        }
    }
}

struct GlossaryTermRow: View {
    let term: GlossaryTerm
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(term.term ?? "")
                .font(.headline)
            
            Text(term.definition ?? "")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            if let category = term.category {
                Text(category)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationView {
        LearnGlossaryView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}