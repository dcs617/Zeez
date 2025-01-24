import SwiftUI
import CoreData

struct LearnReferenceView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var searchText = ""
    @State private var selectedYear: Int?
    @State private var showingYearFilter = false
    
    @FetchRequest<ScientificReference>(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \ScientificReference.year, ascending: false),
            NSSortDescriptor(keyPath: \ScientificReference.title, ascending: true)
        ],
        animation: .default
    ) private var references
    
    private var referencesArray: [ScientificReference] {
        Array(references)
    }
    
    private var years: [Int] {
        Array(Set(referencesArray.compactMap { Int($0.year) })).sorted(by: >)
    }
    
    private var filteredReferences: [ScientificReference] {
        referencesArray.filter { reference in
            let matchesSearch = searchText.isEmpty ||
                (reference.title?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (reference.authors?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (reference.journal?.localizedCaseInsensitiveContains(searchText) ?? false)
            
            let matchesYear = selectedYear == nil || Int(reference.year) == selectedYear
            
            return matchesSearch && matchesYear
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            searchBar
            
            if !referencesArray.isEmpty {
                filterBar
            }
            
            if filteredReferences.isEmpty {
                emptyState
            } else {
                referenceList
            }
        }
        .navigationTitle("References")
        .sheet(isPresented: $showingYearFilter) {
            YearFilterView(selectedYear: $selectedYear, years: years)
        }
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search references", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .padding()
    }
    
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                filterPill(
                    text: selectedYear.map { "\($0)" } ?? "All Years",
                    icon: "calendar",
                    action: { showingYearFilter = true }
                )
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
    
    private func filterPill(text: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(text)
                Image(systemName: "chevron.down")
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.systemGray5))
            .cornerRadius(16)
        }
    }
    
    private var referenceList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredReferences) { reference in
                    ReferenceCard(reference: reference)
                }
            }
            .padding()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text(emptyStateTitle)
                .font(.headline)
            
            Text(emptyStateMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateTitle: String {
        if referencesArray.isEmpty {
            return "No References Available"
        } else if !searchText.isEmpty {
            return "No Matching References"
        } else {
            return "No References Found"
        }
    }
    
    private var emptyStateMessage: String {
        if referencesArray.isEmpty {
            return "References will appear here as you explore content"
        } else if !searchText.isEmpty {
            return "Try adjusting your search terms"
        } else {
            return "Try changing your filters"
        }
    }
}

#Preview {
    NavigationView {
        LearnReferenceView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}