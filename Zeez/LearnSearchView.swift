import SwiftUI
import CoreData

struct LearnSearchView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var selectedFilter: SearchFilter = .all
    
    enum SearchFilter: String, CaseIterable {
        case all = "All"
        case articles = "Articles"
        case notes = "Notes"
        case highlights = "Highlights"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                filterBar
                
                if searchText.isEmpty {
                    searchSuggestions
                } else {
                    LearnSearchResults(searchText: searchText)
                }
            }
            .searchable(text: $searchText, prompt: "Search articles, notes, and highlights")
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(SearchFilter.allCases, id: \.self) { filter in
                    filterButton(for: filter)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
    
    private var searchSuggestions: some View {
        List {
            Section("Recent Searches") {
                ForEach(["Sleep cycles", "REM sleep", "Sleep debt"], id: \.self) { term in
                    Button(action: { searchText = term }) {
                        Label(term, systemImage: "clock")
                    }
                }
            }
            
            Section("Popular Topics") {
                ForEach(["Circadian rhythm", "Sleep hygiene", "Sleep stages"], id: \.self) { topic in
                    Button(action: { searchText = topic }) {
                        Label(topic, systemImage: "star")
                    }
                }
            }
        }
    }
    
    private func filterButton(for filter: SearchFilter) -> some View {
        Button(action: { selectedFilter = filter }) {
            Text(filter.rawValue)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(selectedFilter == filter ? Color.blue : Color(.systemGray5))
                .foregroundColor(selectedFilter == filter ? .white : .primary)
                .cornerRadius(8)
        }
    }
}

#Preview {
    LearnSearchView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
