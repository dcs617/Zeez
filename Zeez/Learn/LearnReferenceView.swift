import SwiftUI
import CoreData
import os.log

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
                .accessibilityLabel("Search")
            
            TextField("Search references", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .accessibilityLabel("Search references")
                .accessibilityHint("Search by title, author, or journal name")
                .accessibilityIdentifier("searchReferencesField")
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("searchBar")
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
                    .accessibilityLabel(icon == "calendar" ? "Year filter" : "Filter")
                Text(text)
                Image(systemName: "chevron.down")
                    .accessibilityLabel("Dropdown")
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.systemGray5))
            .cornerRadius(16)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Filter by \(text.lowercased())")
        .accessibilityHint("Open filter options")
        .accessibilityIdentifier("filterPill_\(text.replacingOccurrences(of: " ", with: "_"))")
    }
    
    private var referenceList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredReferences) { reference in
                    ReferenceCard(reference: reference)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Reference: \(reference.title ?? "Unknown title") by \(reference.authors ?? "Unknown authors")")
                        .accessibilityIdentifier("referenceCard_\(reference.title?.prefix(20).replacingOccurrences(of: " ", with: "_") ?? "unknown")")
                }
            }
            .padding()
        }
        .accessibilityIdentifier("referenceList")
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.gray)
                .accessibilityLabel("No references found")
            
            Text(emptyStateTitle)
                .font(.headline)
            
            Text(emptyStateMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(emptyStateTitle). \(emptyStateMessage)")
        .accessibilityIdentifier("referencesEmptyState")
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
