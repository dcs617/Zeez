import CoreData
import Foundation
import os.log

protocol LearnContentLoader {
    func loadContent(into context: NSManagedObjectContext) throws
}

struct MockLearnContentLoader: LearnContentLoader {
    func loadContent(into context: NSManagedObjectContext) throws {
        let article = LearnArticle(context: context)
        article.id = UUID()
        article.title = "Test Article"
        article.content = "This is a test article for development purposes."
        article.category = LearnCategory.basics.rawValue
        article.readTimeMinutes = 3
        article.sortOrder = 1
        article.createdAt = Date()
        article.modifiedAt = Date()
        
        let challenge = LearnChallenge(context: context)
        challenge.id = UUID()
        challenge.title = "Test Challenge"
        challenge.challengeDescription = "This is a test challenge for development."
        challenge.type = LearnChallengeType.educational.rawValue
        challenge.durationDays = 3
        challenge.points = 50
        challenge.isActive = false
        
        let requirements = ["Requirement 1", "Requirement 2"]
        let encoder = JSONEncoder()
        if let requirementsData = try? encoder.encode(requirements) {
            challenge.requirements = requirementsData
        }
        
        challenge.relatedArticles = NSSet(array: [article])
        
        try context.save()
    }
}

extension PersistenceController {
    static var previewWithLearnContent: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        do {
            try MockLearnContentLoader().loadContent(into: viewContext)
        } catch {
            ZeezLogger.error(ZeezLogger.coreData, "Error creating preview learn content", error: error)
            // Continue with empty content for previews rather than crashing
        }
        
        return result
    }()
}
