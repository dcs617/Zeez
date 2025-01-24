import SwiftUI

struct LearningPath: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let systemIcon: String
    let color: Color
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: LearningPath, rhs: LearningPath) -> Bool {
        lhs.id == rhs.id
    }
}

struct PathTheme {
    static let basics = LearningPath(
        id: "basics",
        name: "Sleep Basics",
        description: "Foundation of healthy sleep",
        systemIcon: "bed.double.fill",
        color: .blue
    )
    
    static let cycles = LearningPath(
        id: "cycles",
        name: "Sleep Cycles",
        description: "Understanding sleep stages",
        systemIcon: "waveform.path.ecg",
        color: .purple
    )
    
    static let environment = LearningPath(
        id: "environment",
        name: "Sleep Environment",
        description: "Optimizing your sleep space",
        systemIcon: "thermometer.sun",
        color: .green
    )
    
    static let advanced = LearningPath(
        id: "advanced",
        name: "Sleep Optimization",
        description: "Advanced techniques and insights",
        systemIcon: "star.fill",
        color: .orange
    )
    
    static let allPaths: [LearningPath] = [
        basics,
        cycles,
        environment,
        advanced
    ]
}