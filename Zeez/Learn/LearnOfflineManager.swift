import SwiftUI
import CoreData
import os.log

class LearnOfflineManager: ObservableObject {
    static let shared = LearnOfflineManager()
    
    @Published var downloadProgress: [NSManagedObjectID: Double] = [:]
    @Published var offlineArticles: Set<NSManagedObjectID> = []
    
    private let defaults = UserDefaults.standard
    private let offlineArticlesKey = "offlineArticles"
    
    init() {
        loadOfflineArticles()
    }
    
    func markForOffline(article: LearnArticle, context: NSManagedObjectContext) {
        guard let id = article.objectID.uriRepresentation().absoluteString.data(using: .utf8) else { return }
        
        var articles = Set(defaults.array(forKey: offlineArticlesKey) as? [Data] ?? [])
        articles.insert(id)
        defaults.set(Array(articles), forKey: offlineArticlesKey)
        
        downloadProgress[article.objectID] = 0
        downloadArticle(article, context: context)
    }
    
    func removeFromOffline(article: LearnArticle) {
        guard let id = article.objectID.uriRepresentation().absoluteString.data(using: .utf8) else { return }
        
        var articles = Set(defaults.array(forKey: offlineArticlesKey) as? [Data] ?? [])
        articles.remove(id)
        defaults.set(Array(articles), forKey: offlineArticlesKey)
        
        offlineArticles.remove(article.objectID)
        downloadProgress.removeValue(forKey: article.objectID)
        deleteCache(for: article)
    }
    
    func isAvailableOffline(article: LearnArticle) -> Bool {
        offlineArticles.contains(article.objectID)
    }
    
    private func loadOfflineArticles() {
        guard let articles = defaults.array(forKey: offlineArticlesKey) as? [Data] else { return }
              
        let coordinator = PersistenceController.shared.container.persistentStoreCoordinator
        
        offlineArticles = Set(articles.compactMap { articleId in
            guard let urlString = String(data: articleId, encoding: .utf8),
                  let url = URL(string: urlString),
                  let objectID = coordinator.managedObjectID(forURIRepresentation: url) else {
                return nil
            }
            return objectID
        })
    }
    
    private func downloadArticle(_ article: LearnArticle, context: NSManagedObjectContext) {
        // Cache the article content
        let cache = ArticleCache(
            title: article.title,
            content: article.content,
            category: article.category,
            readTimeMinutes: Int(article.readTimeMinutes),
            quiz: cacheQuiz(article.quiz),
            references: cacheReferences(article.references?.allObjects as? [ScientificReference] ?? [])
        )
        
        // Simulated download with actual caching
        var progress: Double = 0
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            progress += 0.1
            self?.downloadProgress[article.objectID] = min(progress, 1.0)
            
            if progress >= 1.0 {
                timer.invalidate()
                if let encoded = try? JSONEncoder().encode(cache) {
                    try? encoded.write(to: self?.getCacheURL(for: article) ?? URL(fileURLWithPath: ""))
                }
                self?.offlineArticles.insert(article.objectID)
                self?.downloadProgress.removeValue(forKey: article.objectID)
            }
        }
    }
    
    private func cacheQuiz(_ quiz: Quiz?) -> QuizCache? {
        guard let quiz = quiz else { return nil }
        
        return QuizCache(
            title: quiz.title,
            description: quiz.quizDescription,
            passingScore: Int(quiz.passingScore),
            questions: quiz.questions?.allObjects.compactMap { question in
                guard let q = question as? QuizQuestion else { return nil }
                return QuizQuestionCache(
                    question: q.question,
                    explanation: q.explanation,
                    answers: q.answers?.allObjects.compactMap { answer in
                        guard let a = answer as? QuizAnswer else { return nil }
                        return QuizAnswerCache(
                            text: a.text,
                            isCorrect: a.isCorrect
                        )
                    } ?? []
                )
            } ?? []
        )
    }
    
    private func cacheReferences(_ references: [ScientificReference]) -> [ReferenceCache] {
        references.map { ref in
            ReferenceCache(
                title: ref.title,
                authors: ref.authors,
                journal: ref.journal,
                year: Int(ref.year),
                doi: ref.doi,
                citation: ref.citation
            )
        }
    }
    
    private func deleteCache(for article: LearnArticle) {
        try? FileManager.default.removeItem(at: getCacheURL(for: article))
    }
    
    private func getCacheURL(for article: LearnArticle) -> URL {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return cacheDir.appendingPathComponent("article_\(article.objectID.uriRepresentation().absoluteString.hash)")
    }
    
    func loadCachedArticle(_ article: LearnArticle) -> ArticleCache? {
        guard let data = try? Data(contentsOf: getCacheURL(for: article)),
              let cache = try? JSONDecoder().decode(ArticleCache.self, from: data) else {
            return nil
        }
        return cache
    }
}

// MARK: - Cache Models
struct ArticleCache: Codable {
    let title: String?
    let content: String?
    let category: String?
    let readTimeMinutes: Int
    let quiz: QuizCache?
    let references: [ReferenceCache]
}

struct QuizCache: Codable {
    let title: String?
    let description: String?
    let passingScore: Int
    let questions: [QuizQuestionCache]
}

struct QuizQuestionCache: Codable {
    let question: String?
    let explanation: String?
    let answers: [QuizAnswerCache]
}

struct QuizAnswerCache: Codable {
    let text: String?
    let isCorrect: Bool
}

struct ReferenceCache: Codable {
    let title: String?
    let authors: String?
    let journal: String?
    let year: Int
    let doi: String?
    let citation: String?
}

// MARK: - UI Components
struct OfflineButton: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var manager = LearnOfflineManager.shared
    let article: LearnArticle
    
    var body: some View {
        Group {
            if let progress = manager.downloadProgress[article.objectID] {
                ProgressView(value: progress) {
                    Image(systemName: "arrow.down.circle")
                }
                .tint(.blue)
                .frame(width: 24, height: 24)
            } else {
                Button(action: toggleOffline) {
                    Image(systemName: manager.isAvailableOffline(article: article) ? 
                          "arrow.down.circle.fill" : "arrow.down.circle")
                }
                .foregroundColor(manager.isAvailableOffline(article: article) ? .blue : .gray)
            }
        }
    }
    
    private func toggleOffline() {
        if manager.isAvailableOffline(article: article) {
            manager.removeFromOffline(article: article)
        } else {
            manager.markForOffline(article: article, context: viewContext)
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let article = LearnArticle(context: context)
    article.title = "Sample Article"
    return OfflineButton(article: article)
        .environment(\.managedObjectContext, context)
}
