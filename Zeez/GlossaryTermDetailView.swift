import SwiftUI
import CoreData

struct GlossaryTermDetailView: View {
    let term: GlossaryTerm
    @State private var showingRelatedTerms = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                termHeader
                definitionSection
                if hasRelatedContent {
                    relatedContent
                }
            }
            .padding()
        }
        .navigationTitle(term.term ?? "Term")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var termHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(term.term ?? "")
                .font(.title)
                .fontWeight(.bold)
            
            if let category = term.category {
                Text(category)
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(16)
            }
            
            Divider()
        }
    }
    
    private var definitionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Definition")
                .font(.headline)
            
            Text(term.definition ?? "")
                .font(.body)
                .lineSpacing(4)
        }
    }
    
    private var hasRelatedContent: Bool {
        (term.relatedTerms?.count ?? 0) > 0 || 
        (term.relatedArticles?.count ?? 0) > 0
    }
    
    private var relatedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let relatedTerms = term.relatedTerms?.allObjects as? [GlossaryTerm],
               !relatedTerms.isEmpty {
                relatedTermsSection(terms: relatedTerms)
            }
            
            if let articles = term.relatedArticles?.allObjects as? [LearnArticle],
               !articles.isEmpty {
                relatedArticlesSection(articles: articles)
            }
        }
    }
    
    private func relatedTermsSection(terms: [GlossaryTerm]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Related Terms")
                .font(.headline)
            
            ForEach(terms) { relatedTerm in
                NavigationLink(destination: GlossaryTermDetailView(term: relatedTerm)) {
                    HStack {
                        Text(relatedTerm.term ?? "")
                            .font(.subheadline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    private func relatedArticlesSection(articles: [LearnArticle]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Learn More")
                .font(.headline)
            
            ForEach(articles) { article in
                NavigationLink(destination: LearnArticleDetailView(articleId: article.objectID)) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(article.title ?? "")
                                .font(.subheadline)
                            Text("\(article.readTimeMinutes) min read")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
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

#Preview {
    NavigationView {
        GlossaryTermDetailView(term: GlossaryTerm())
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}