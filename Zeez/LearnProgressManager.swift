import CoreData
import Foundation

class LearnProgressManager {
    static let shared = LearnProgressManager()
    
    private init() {}
    
    // MARK: - Article Progress
    
    func updateArticleProgress(for article: LearnArticle, context: NSManagedObjectContext) {
        context.perform {
            let progress = self.fetchOrCreateArticleProgress(for: article, context: context)
            progress.lastReadDate = Date()
            progress.isCompleted = true
            
            do {
                try context.save()
            } catch {
                print("Error updating article progress: \(error)")
            }
        }
    }
    
    func toggleBookmark(for article: LearnArticle, context: NSManagedObjectContext) {
        context.perform {
            let progress = self.fetchOrCreateArticleProgress(for: article, context: context)
            progress.bookmarked.toggle()
            
            do {
                try context.save()
            } catch {
                print("Error toggling bookmark: \(error)")
            }
        }
    }
    
    // MARK: - Challenge Progress
    
    func startChallenge(_ challenge: LearnChallenge, context: NSManagedObjectContext) {
        context.perform {
            challenge.isActive = true
            challenge.startDate = Date()
            challenge.endDate = Calendar.current.date(byAdding: .day, value: Int(challenge.durationDays), to: Date())
            
            let badge = ChallengeBadge(context: context)
            badge.id = UUID()
            badge.challenge = challenge
            badge.progress = 0
            badge.isCompleted = false
            
            do {
                try context.save()
            } catch {
                print("Error starting challenge: \(error)")
            }
        }
    }
    
    func updateChallengeProgress(_ challenge: LearnChallenge, progress: Double, context: NSManagedObjectContext) {
        guard let badge = challenge.userProgress else { return }
        
        context.perform {
            badge.progress = progress
            
            if progress >= 1.0 {
                badge.isCompleted = true
                badge.earnedDate = Date()
                challenge.isActive = false
            }
            
            do {
                try context.save()
            } catch {
                print("Error updating challenge progress: \(error)")
            }
        }
    }
    
    // MARK: - Achievement Tracking
    
    func checkForAchievements(context: NSManagedObjectContext) {
        context.perform {
            self.checkReadingStreak(context: context)
            self.checkChallengeCompletion(context: context)
            self.checkCategoryCompletion(context: context)
        }
    }
    
    // MARK: - Private Helpers
    
    private func fetchOrCreateArticleProgress(for article: LearnArticle, context: NSManagedObjectContext) -> UserArticleProgress {
        let fetchRequest: NSFetchRequest<UserArticleProgress> = UserArticleProgress.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "article == %@", article)
        
        do {
            if let existing = try context.fetch(fetchRequest).first {
                return existing
            }
        } catch {
            print("Error fetching article progress: \(error)")
        }
        
        let progress = UserArticleProgress(context: context)
        progress.id = UUID()
        progress.article = article
        return progress
    }
    
    private func checkReadingStreak(context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<UserArticleProgress> = UserArticleProgress.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "lastReadDate > %@", 
            Calendar.current.date(byAdding: .day, value: -7, to: Date())! as NSDate)
        
        do {
            let recentProgress = try context.fetch(fetchRequest)
            let uniqueDays = Set(recentProgress.compactMap { progress in
                Calendar.current.startOfDay(for: progress.lastReadDate ?? Date())
            })
            
            if uniqueDays.count >= 7 {
                // Award reading streak achievement
                print("7-day reading streak achieved!")
            }
        } catch {
            print("Error checking reading streak: \(error)")
        }
    }
    
    private func checkChallengeCompletion(context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<ChallengeBadge> = ChallengeBadge.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isCompleted == YES")
        
        do {
            let completedChallenges = try context.fetch(fetchRequest)
            if completedChallenges.count >= 5 {
                // Award challenge master achievement
                print("Challenge master achievement unlocked!")
            }
        } catch {
            print("Error checking challenge completion: \(error)")
        }
    }
    
    private func checkCategoryCompletion(context: NSManagedObjectContext) {
        for category in LearnCategory.allCases {
            let fetchRequest: NSFetchRequest<LearnArticle> = LearnArticle.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "category == %@", category.rawValue)
            
            do {
                let articles = try context.fetch(fetchRequest)
                let completedArticles = articles.filter { article in
                    article.userProgress?.isCompleted == true
                }
                
                if completedArticles.count == articles.count && !articles.isEmpty {
                    // Award category completion achievement
                    print("Category \(category.rawValue) completed!")
                }
            } catch {
                print("Error checking category completion: \(error)")
            }
        }
    }
}