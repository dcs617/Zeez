import CoreData
import Combine

/// Tracks and manages environmental recommendations over time
class EnvironmentalRecommendationTracker {
    static let shared = EnvironmentalRecommendationTracker()
    
    private let context: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()
    
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
    }
    
    /// Save recommendations from an analysis
    func saveRecommendations(
        _ recommendations: [EnvironmentalRecommendation],
        for session: SleepSession
    ) {
        // Create note for recommendations
        let note = SleepNote(context: context)
        note.id = UUID()
        note.timestamp = Date()
        note.session = session
        note.category = "environmental"
        
        // Format recommendations
        let content = recommendations
            .map { "• \($0.description)" }
            .joined(separator: "\n")
        
        note.content = """
        Environmental Recommendations:
        \(content)
        """
        
        try? context.save()
    }
    
    /// Get persistent recommendations (appearing in multiple sessions)
    func getPersistentRecommendations() async throws -> [RecommendationTrend] {
        let request: NSFetchRequest<SleepNote> = SleepNote.fetchRequest()
        request.predicate = NSPredicate(format: "category == %@", "environmental")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SleepNote.timestamp, ascending: false)]
        
        let notes = try context.fetch(request)
        var recommendationCounts: [String: Int] = [:]
        
        // Count occurrences of each recommendation
        for note in notes {
            guard let content = note.content else { continue }
            let recommendations = parseRecommendations(from: content)
            
            for recommendation in recommendations {
                recommendationCounts[recommendation, default: 0] += 1
            }
        }
        
        // Convert to trends
        return recommendationCounts
            .map { recommendation, count in
                RecommendationTrend(
                    recommendation: recommendation,
                    occurrences: count,
                    frequency: Double(count) / Double(notes.count)
                )
            }
            .sorted { $0.occurrences > $1.occurrences }
    }
    
    /// Get improvement tracking for a specific recommendation
    func trackImprovement(for recommendation: String) async throws -> ImprovementTracking {
        let request: NSFetchRequest<SleepNote> = SleepNote.fetchRequest()
        request.predicate = NSPredicate(
            format: "category == %@ AND content CONTAINS[c] %@",
            "environmental",
            recommendation
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SleepNote.timestamp, ascending: true)]
        
        let notes = try context.fetch(request)
        var improvements: [Date: Double] = [:]
        
        for note in notes {
            guard let session = note.session,
                  let timestamp = note.timestamp else { continue }
            
            // Track quality scores over time for sessions with this recommendation
            improvements[timestamp] = session.qualityScore
        }
        
        // Calculate trend
        let trend: ImprovementTrend
        if improvements.count >= 2,
           let firstScore = improvements.min(by: { $0.key < $1.key })?.value,
           let lastScore = improvements.max(by: { $0.key < $1.key })?.value {
            let change = lastScore - firstScore
            trend = change > 0 ? .improving : change < 0 ? .declining : .stable
        } else {
            trend = .insufficient
        }
        
        return ImprovementTracking(
            dataPoints: improvements,
            trend: trend
        )
    }
    
    // MARK: - Private Methods
    
    private func parseRecommendations(from content: String) -> [String] {
        return content
            .components(separatedBy: .newlines)
            .filter { $0.hasPrefix("•") }
            .map { String($0.dropFirst(2)) }
    }
}

// MARK: - Supporting Types

struct RecommendationTrend {
    let recommendation: String
    let occurrences: Int
    let frequency: Double
}

struct ImprovementTracking {
    let dataPoints: [Date: Double]
    let trend: ImprovementTrend
}

enum ImprovementTrend {
    case improving
    case declining
    case stable
    case insufficient
    
    var description: String {
        switch self {
        case .improving:
            return "Showing improvement"
        case .declining:
            return "Needs attention"
        case .stable:
            return "Maintaining level"
        case .insufficient:
            return "Need more data"
        }
    }
    
    var icon: String {
        switch self {
        case .improving: return "arrow.up.circle.fill"
        case .declining: return "arrow.down.circle.fill"
        case .stable: return "equal.circle.fill"
        case .insufficient: return "questionmark.circle.fill"
        }
    }
}