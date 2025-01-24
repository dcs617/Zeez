import CoreData
import SwiftUI

class LearningPathManager {
    static let shared = LearningPathManager()
    
    private init() {}
    
    func calculatePathProgress(pathId: String, context: NSManagedObjectContext) -> Double {
        // Get all articles in this path
        let articlesRequest: NSFetchRequest<LearnArticle> = LearnArticle.fetchRequest()
        articlesRequest.predicate = NSPredicate(format: "category == %@", pathId)
        
        guard let articles = try? context.fetch(articlesRequest) else { return 0 }
        guard !articles.isEmpty else { return 0 }
        
        let completedCount = articles.filter { $0.userProgress?.isCompleted == true }.count
        return Double(completedCount) / Double(articles.count)
    }
    
    func getNextModule(forPath pathId: String, context: NSManagedObjectContext) -> LearnArticle? {
        let request: NSFetchRequest<LearnArticle> = LearnArticle.fetchRequest()
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "category == %@", pathId),
            NSPredicate(format: "userProgress.isCompleted == NO OR userProgress == nil")
        ])
        request.sortDescriptors = [NSSortDescriptor(keyPath: \LearnArticle.sortOrder, ascending: true)]
        request.fetchLimit = 1
        
        return try? context.fetch(request).first
    }
    
    func getPathArticles(pathId: String, context: NSManagedObjectContext) -> [LearnArticle] {
        let request: NSFetchRequest<LearnArticle> = LearnArticle.fetchRequest()
        request.predicate = NSPredicate(format: "category == %@", pathId)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \LearnArticle.sortOrder, ascending: true)]
        
        return (try? context.fetch(request)) ?? []
    }
    
    func markModuleComplete(article: LearnArticle, context: NSManagedObjectContext) {
        if article.userProgress == nil {
            let progress = UserArticleProgress(context: context)
            progress.id = UUID()
            progress.article = article
            progress.lastReadDate = Date()
        }
        
        article.userProgress?.isCompleted = true
        article.userProgress?.lastReadDate = Date()
        
        try? context.save()
    }
}
