import SwiftUI

enum SleepPosition: String {
    case back = "Back"
    case leftSide = "Left Side"
    case rightSide = "Right Side"
    case stomach = "Stomach"
    
    var icon: String {
        switch self {
        case .back: return "figure.child.and.arrow.up.right"
        case .leftSide, .rightSide: return "figure.walk"
        case .stomach: return "figure.walk.arrival"
        }
    }
    
    var impactScore: Int {
        switch self {
        case .back: return 85     // Generally considered good for spine alignment
        case .leftSide: return 90 // Best for digestion and heart health
        case .rightSide: return 80 // Good but slightly less optimal than left
        case .stomach: return 60   // Generally considered least optimal
        }
    }
    
    var benefits: [String] {
        switch self {
        case .back:
            return [
                "Maintains spine alignment",
                "Reduces acid reflux",
                "Minimizes facial wrinkles",
                "Helps prevent neck and back pain"
            ]
        case .leftSide:
            return [
                "Improves digestion",
                "Reduces heartburn",
                "Benefits heart health",
                "Promotes lymphatic drainage"
            ]
        case .rightSide:
            return [
                "Good for spinal alignment",
                "Reduces snoring",
                "Can help with digestion",
                "May reduce heart pressure"
            ]
        case .stomach:
            return [
                "Can reduce snoring",
                "May help with sleep apnea",
                "Natural position for some",
                "Can ease breathing"
            ]
        }
    }
    
    var drawbacks: [String] {
        switch self {
        case .back:
            return [
                "May increase snoring",
                "Not ideal for sleep apnea",
                "Can be uncomfortable initially",
                "Might worsen lower back pain"
            ]
        case .leftSide:
            return [
                "Can cause shoulder pain",
                "May strain internal organs",
                "Might cause arm numbness",
                "Can create facial wrinkles"
            ]
        case .rightSide:
            return [
                "Less optimal for digestion",
                "May cause shoulder pain",
                "Can strain internal organs",
                "Might cause arm numbness"
            ]
        case .stomach:
            return [
                "Strains neck and spine",
                "Can cause back pain",
                "Puts pressure on joints",
                "May cause facial wrinkles"
            ]
        }
    }
}