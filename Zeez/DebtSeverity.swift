import SwiftUI

enum DebtSeverity: String {
    case minimal = "Minimal"
    case moderate = "Moderate"
    case significant = "Significant"
    case severe = "Severe"
    
    var color: Color {
        switch self {
        case .minimal: return .green
        case .moderate: return .yellow
        case .significant: return .orange
        case .severe: return .red
        }
    }
    
    var description: String {
        switch self {
        case .minimal:
            return "Minor sleep debt that can be recovered with one good night's sleep"
        case .moderate:
            return "Noticeable sleep debt that requires a few days of consistent sleep to recover"
        case .significant:
            return "Substantial sleep debt that needs immediate attention and a recovery plan"
        case .severe:
            return "Critical sleep debt levels - consult a healthcare professional"
        }
    }
    
    var impacts: [String] {
        switch self {
        case .minimal:
            return [
                "Slightly reduced alertness",
                "Minor mood changes"
            ]
        case .moderate:
            return [
                "Decreased concentration",
                "Impaired memory",
                "Mood swings",
                "Reduced reaction time"
            ]
        case .significant:
            return [
                "Significant fatigue",
                "Impaired decision making",
                "Emotional instability",
                "Weakened immune system",
                "Increased stress levels"
            ]
        case .severe:
            return [
                "Severe cognitive impairment",
                "High risk of accidents",
                "Compromised immune system",
                "Mental health impacts",
                "Cardiovascular strain",
                "Metabolic disruption"
            ]
        }
    }
    
    var recommendations: [String] {
        switch self {
        case .minimal:
            return [
                "Maintain current sleep schedule",
                "Aim for consistent bedtime"
            ]
        case .moderate:
            return [
                "Add 30-60 minutes to nightly sleep",
                "Prioritize sleep hygiene",
                "Consider a weekend recovery period"
            ]
        case .significant:
            return [
                "Increase sleep by 1-2 hours nightly",
                "Implement strict sleep schedule",
                "Eliminate sleep disruptors",
                "Consider talking to a sleep specialist"
            ]
        case .severe:
            return [
                "Seek professional medical advice",
                "Immediate sleep schedule adjustment",
                "Consider time off for recovery",
                "Track sleep patterns closely",
                "Eliminate all non-essential activities"
            ]
        }
    }
}