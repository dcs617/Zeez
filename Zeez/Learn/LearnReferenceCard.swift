import SwiftUI
import CoreData
import os.log

struct ReferenceCard: View {
    let reference: ScientificReference
    @State private var showingDetail = false
    
    var body: some View {
        Button(action: { showingDetail = true }) {
            VStack(alignment: .leading, spacing: 8) {
                // Title and Year
                HStack(alignment: .top) {
                    Text(reference.title ?? "")
                        .font(.headline)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    Text(String(reference.year))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                }
                
                // Authors
                if let authors = reference.authors {
                    Text(authors)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // Journal and DOI/URL
                HStack {
                    if let journal = reference.journal {
                        Text(journal)
                            .italic()
                    }
                    
                    if reference.doi != nil || reference.url != nil {
                        Image(systemName: "link")
                            .foregroundColor(.blue)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetail) {
            ReferenceDetailView(reference: reference)
        }
    }
}

struct ReferenceDetailView: View {
    let reference: ScientificReference
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Title Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text(reference.title ?? "")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if let authors = reference.authors {
                            Text(authors)
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        
                        if let journal = reference.journal {
                            Text(journal)
                                .font(.subheadline)
                                .italic()
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Label(String(reference.year), systemImage: "calendar")
                            
                            if let doi = reference.doi {
                                Button(action: { openDOI(doi) }) {
                                    Label("DOI", systemImage: "link")
                                }
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // Abstract Section
                    if let abstract = reference.abstract {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Abstract")
                                .font(.headline)
                            
                            Text(abstract)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Citation Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Citation")
                            .font(.headline)
                        
                        Text(reference.citation ?? "")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    
                    // Related Articles Section
                    if let articles = reference.articles?.allObjects as? [LearnArticle],
                       !articles.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Referenced In")
                                .font(.headline)
                            
                            ForEach(articles) { article in
                                NavigationLink(destination: LearnArticleDetailView(articleId: article.objectID)) {
                                    Text(article.title ?? "")
                                        .font(.subheadline)
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Reference")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func openDOI(_ doi: String) {
        if let url = URL(string: "https://doi.org/\(doi)") {
            openURL(url)
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let reference = ScientificReference(context: context)
    reference.title = "Sample Reference"
    reference.authors = "John Doe, Jane Smith"
    reference.journal = "Journal of Sleep Research"
    reference.year = 2024
    return ReferenceCard(reference: reference)
        .padding()
        .environment(\.managedObjectContext, context)
}
