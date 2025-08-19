import SwiftUI
import CoreData
import os.log

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
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("glossaryTermTitle")
            
            if let category = term.category {
                Text(category)
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(16)
                    .accessibilityLabel("Category: \(category)")
                    .accessibilityIdentifier("glossaryTermCategory")
            }
            
            Divider()
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("termHeader")
    }
    
    private var definitionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Definition")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("definitionHeader")
            
            Text(term.definition ?? "")
                .font(.body)
                .lineSpacing(4)
                .accessibilityLabel("Definition: \(term.definition ?? "")")
                .accessibilityIdentifier("glossaryTermDefinition")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("definitionSection")
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
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("relatedTermsHeader")
            
            ForEach(terms) { relatedTerm in
                NavigationLink(destination: GlossaryTermDetailView(term: relatedTerm)) {
                    HStack {
                        Text(relatedTerm.term ?? "")
                            .font(.subheadline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                            .accessibilityHidden(true)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .accessibilityLabel("View definition of \(relatedTerm.term ?? "")")
                .accessibilityHint("Navigate to detailed view of related term")
                .accessibilityIdentifier("relatedTerm_\(relatedTerm.term?.replacingOccurrences(of: " ", with: "").lowercased() ?? "")")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("relatedTermsSection")
    }
    
    private func relatedArticlesSection(articles: [LearnArticle]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Learn More")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("learnMoreHeader")
            
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
                            .accessibilityHidden(true)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .accessibilityLabel("Read article: \(article.title ?? ""), \(article.readTimeMinutes) minute read")
                .accessibilityHint("Navigate to full article view")
                .accessibilityIdentifier("relatedArticle_\(article.title?.replacingOccurrences(of: " ", with: "").lowercased() ?? "")")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("relatedArticlesSection")
    }
}

#Preview {
    NavigationView {
        GlossaryTermDetailView(term: GlossaryTerm())
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
