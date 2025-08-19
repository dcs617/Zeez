import SwiftUI
import os.log

enum HeartRateTimeRange: String, CaseIterable, Identifiable {
    case hour = "1h"
    case threeHours = "3h"
    case all = "All"
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .hour: return "1 Hour"
        case .threeHours: return "3 Hours"
        case .all: return "All"
        }
    }
}

struct HeartRateDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let confidence: Double
}

struct DetailedHeartRateStats {
    let average: Int
    let averageTrend: HeartRateTrendDirection
    let resting: Int
    let restingTrend: HeartRateTrendDirection
    let minimum: Int
    let maximum: Int
}

enum HeartRateTrendDirection {
    case up, down, neutral
    
    var icon: String {
        switch self {
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        case .neutral: return "arrow.forward"
        }
    }
    
    var color: Color {
        switch self {
        case .up: return .red
        case .down: return .green
        case .neutral: return .gray
        }
    }
}

struct HeartRateZone: Identifiable {
    let id: Int
    let name: String
    let range: String
    let percentage: Double
    let color: Color
}

struct StageCorrelation: Identifiable {
    let id = UUID()
    let stageName: String
    let averageHR: Int
    let timeSpent: TimeInterval
    let color: Color
}

struct HRVDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct HRVData {
    let average: Double
    let quality: HRVQuality
    let timeData: [HRVDataPoint]
}

enum HRVQuality {
    case poor, fair, good, excellent
    
    var label: String {
        switch self {
        case .poor: return "Poor"
        case .fair: return "Fair"
        case .good: return "Good"
        case .excellent: return "Excellent"
        }
    }
    
    var color: Color {
        switch self {
        case .poor: return .red
        case .fair: return .orange
        case .good: return .green
        case .excellent: return .blue
        }
    }
}
