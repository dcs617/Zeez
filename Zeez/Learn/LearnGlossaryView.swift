import SwiftUI
import CoreData
import os.log

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
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Glossary term: \(term.term ?? "Unknown term")")
                    .accessibilityHint("Double tap to view definition and details")
                    .accessibilityIdentifier("glossaryTerm_\(term.term?.replacingOccurrences(of: " ", with: "_") ?? "unknown")")
                }
            }
            .accessibilityLabel("Glossary terms list")
            .accessibilityHint("List of sleep-related terms and definitions")
            .accessibilityIdentifier("glossaryTermsList")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sleep glossary view")
        .accessibilityHint("Search and browse sleep-related terms and definitions")
        .accessibilityIdentifier("glossaryView")
        .navigationTitle("Sleep Glossary")
        .navigationBarTitleDisplayMode(.large)
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search terms", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .accessibilityLabel("Search glossary terms")
                .accessibilityHint("Enter text to search for sleep terms and definitions")
                .accessibilityIdentifier("glossarySearchField")
        }
        .padding()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Search bar")
        .accessibilityHint("Search for glossary terms")
        .accessibilityIdentifier("searchBar")
    }
    
    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                categoryButton(nil)
                .accessibilityLabel("Show all terms")
                .accessibilityHint("Show terms from all categories")
                .accessibilityIdentifier("allCategoriesButton")
                
                ForEach(categories, id: \.self) { category in
                    categoryButton(category)
                        .accessibilityLabel("Filter by \(category) category")
                        .accessibilityHint("Show only terms in the \(category) category")
                        .accessibilityIdentifier("categoryFilter_\(category.replacingOccurrences(of: " ", with: "_"))")
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
        .accessibilityLabel(category == nil ? "Show all terms" : "Filter by \(category!) category")
        .accessibilityHint(category == nil ? "Show terms from all categories" : "Show only terms in the \(category!) category")
        .accessibilityIdentifier("categoryButton_\(category?.replacingOccurrences(of: " ", with: "_") ?? "all")")
    }
}

struct GlossaryTermRow: View {
    let term: GlossaryTerm
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(term.term ?? "")
                .font(.headline)
                .accessibilityLabel("Term: \(term.term ?? "Unknown")")
                .accessibilityIdentifier("termName")
            
            Text(term.definition ?? "")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .accessibilityLabel("Definition: \(term.definition ?? "No definition")")
                .accessibilityIdentifier("termDefinition")
            
            if let category = term.category {
                Text(category)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .clipShape(Capsule())
                    .accessibilityLabel("Category: \(category)")
                    .accessibilityIdentifier("termCategory")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(term.term ?? "Unknown term"): \(term.definition ?? "No definition")")
        .accessibilityIdentifier("glossaryTermRow")
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationView {
        LearnGlossaryView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
