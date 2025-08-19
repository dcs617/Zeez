import Foundation
import CoreData
import os.log

/// Represents the main categories in the Learn section
enum LearnCategory: String, CaseIterable {
    case basics = "Sleep Basics"
    case optimization = "Optimization"
    case science = "Sleep Science"
    case challenges = "Challenges"
    
    var systemIcon: String {
        switch self {
        case .basics:
            return "bed.double.fill"
        case .optimization:
            return "chart.line.uptrend.xyaxis"
        case .science:
            return "brain.head.profile"
        case .challenges:
            return "trophy.fill"
        }
    }
    
    var description: String {
        switch self {
        case .basics:
            return "Learn the fundamentals of healthy sleep habits"
        case .optimization:
            return "Discover ways to improve your sleep quality"
        case .science:
            return "Understand the science behind sleep"
        case .challenges:
            return "Complete challenges to build better sleep habits"
        }
    }
}

/// Represents a challenge type in the Learn section
enum LearnChallengeType: String {
    case educational = "Educational"
    case behavioral = "Behavioral"
}

/// Represents the view state for the Learn tab
enum LearnViewState: Equatable {
    case categoryList
    case articleList(LearnCategory)
    case articleDetail(NSManagedObjectID)
    case challengeList
    case challengeDetail(NSManagedObjectID)
}
