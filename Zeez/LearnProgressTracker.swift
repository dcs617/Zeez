import SwiftUI
import CoreData

class LearnProgressTracker: ObservableObject {
    static let shared = LearnProgressTracker()
    
    @Published var latestProgress: [NSManagedObjectID: Double] = [:]
    private var progressTimers: [NSManagedObjectID: Timer] = [:]
    
    func startTracking(article: LearnArticle, in context: NSManagedObjectContext) {
        // Create or get progress
        let progress = article.userProgress ?? UserArticleProgress(context: context)
        progress.article = article
        if progress.lastReadDate == nil {
            progress.lastReadDate = Date()
        }
        
        // Start tracking timer
        let timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.updateProgress(for: article, in: context)
        }
        progressTimers[article.objectID] = timer
    }
    
    func stopTracking(article: LearnArticle) {
        progressTimers[article.objectID]?.invalidate()
        progressTimers.removeValue(forKey: article.objectID)
    }
    
    private func updateProgress(for article: LearnArticle, in context: NSManagedObjectContext) {
        guard let progress = article.userProgress else { return }
        
        progress.lastReadDate = Date()
        
        // Mark as completed if they've been reading for a while
        if let startDate = progress.lastReadDate,
           Date().timeIntervalSince(startDate) > TimeInterval(Double(article.readTimeMinutes) * 60.0 * 0.7) {
            progress.isCompleted = true
        }
        
        do {
            try context.save()
            objectWillChange.send()
        } catch {
            print("Error saving progress: \(error)")
        }
    }
    
    func calculateProgress(for article: LearnArticle) -> Double {
        guard let progress = article.userProgress,
              let startDate = progress.lastReadDate else {
            return 0
        }
        
        let totalSeconds = Double(article.readTimeMinutes) * 60.0
        let elapsedSeconds = Date().timeIntervalSince(startDate)
        return min(elapsedSeconds / totalSeconds, 1.0)
    }
    
    func markComplete(article: LearnArticle, in context: NSManagedObjectContext) {
        let progress = article.userProgress ?? UserArticleProgress(context: context)
        progress.article = article
        progress.isCompleted = true
        progress.lastReadDate = Date()
        
        do {
            try context.save()
            objectWillChange.send()
        } catch {
            print("Error marking article complete: \(error)")
        }
    }
    
    func toggleBookmark(article: LearnArticle, in context: NSManagedObjectContext) {
        let progress = article.userProgress ?? UserArticleProgress(context: context)
        progress.article = article
        progress.bookmarked.toggle()
        
        do {
            try context.save()
            objectWillChange.send()
        } catch {
            print("Error toggling bookmark: \(error)")
        }
    }
    
    func getCurrentStreak(context: NSManagedObjectContext) -> Int {
        let fetchRequest: NSFetchRequest<UserArticleProgress> = UserArticleProgress.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \UserArticleProgress.lastReadDate, ascending: false)]
        
        guard let progress = try? context.fetch(fetchRequest) else { return 0 }
        
        var currentStreak = 0
        var lastDate: Date?
        let calendar = Calendar.current
        
        for article in progress {
            guard let readDate = article.lastReadDate else { continue }
            
            if let last = lastDate {
                let daysBetween = calendar.dateComponents([.day], from: readDate, to: last).day ?? 0
                if daysBetween > 1 { break }
            }
            
            lastDate = readDate
            currentStreak += 1
        }
        
        return currentStreak
    }
    
    func calculateOverallProgress(context: NSManagedObjectContext) -> Double {
        let articleRequest: NSFetchRequest<LearnArticle> = LearnArticle.fetchRequest()
        let progressRequest: NSFetchRequest<UserArticleProgress> = UserArticleProgress.fetchRequest()
        progressRequest.predicate = NSPredicate(format: "isCompleted == YES")
        
        guard let totalArticles = try? context.count(for: articleRequest),
              let completedArticles = try? context.count(for: progressRequest),
              totalArticles > 0 else {
            return 0
        }
        
        return Double(completedArticles) / Double(totalArticles)
    }
    
    func calculateOverallProgress(in category: LearnCategory, context: NSManagedObjectContext) -> Double {
        let articleRequest: NSFetchRequest<LearnArticle> = LearnArticle.fetchRequest()
        articleRequest.predicate = NSPredicate(format: "category == %@", category.rawValue)
        
        let progressRequest: NSFetchRequest<UserArticleProgress> = UserArticleProgress.fetchRequest()
        progressRequest.predicate = NSPredicate(format: "isCompleted == YES AND article.category == %@", category.rawValue)
        
        guard let totalArticles = try? context.count(for: articleRequest),
              let completedArticles = try? context.count(for: progressRequest),
              totalArticles > 0 else {
            return 0
        }
        
        return Double(completedArticles) / Double(totalArticles)
    }
}

struct LearnProgressIndicator: View {
    @ObservedObject var tracker = LearnProgressTracker.shared
    let article: LearnArticle
    
    var body: some View {
        if let progress = article.userProgress,
           progress.isCompleted {
            Label("Completed", systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
        } else {
            ProgressView(value: tracker.calculateProgress(for: article))
                .tint(.blue)
        }
    }
}

struct LearnBookmarkButton: View {
    @Environment(\.managedObjectContext) private var viewContext
    let article: LearnArticle
    
    var body: some View {
        Button(action: toggleBookmark) {
            Image(systemName: article.userProgress?.bookmarked == true ? "bookmark.fill" : "bookmark")
                .foregroundColor(article.userProgress?.bookmarked == true ? .blue : .gray)
        }
    }
    
    private func toggleBookmark() {
        LearnProgressTracker.shared.toggleBookmark(article: article, in: viewContext)
    }
}

struct LearnReadingControls: View {
    @Environment(\.managedObjectContext) private var viewContext
    let article: LearnArticle
    
    var body: some View {
        HStack {
            LearnProgressIndicator(article: article)
            
            Spacer()
            
            if article.userProgress?.isCompleted != true {
                Button(action: markComplete) {
                    Text("Mark as Read")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            
            LearnBookmarkButton(article: article)
        }
        .onAppear {
            LearnProgressTracker.shared.startTracking(article: article, in: viewContext)
        }
        .onDisappear {
            LearnProgressTracker.shared.stopTracking(article: article)
        }
    }
    
    private func markComplete() {
        LearnProgressTracker.shared.markComplete(article: article, in: viewContext)
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let article = LearnArticle(context: context)
    article.title = "Sample Article"
    article.readTimeMinutes = 5
    return LearnReadingControls(article: article)
        .padding()
        .environment(\.managedObjectContext, context)
}