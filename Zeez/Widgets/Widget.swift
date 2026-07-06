import SwiftUI
import os.log

// Protocol that all widgets must conform to
protocol Widget: Identifiable {
    var id: UUID { get }
    var title: String { get }
    var type: WidgetType { get }
    var requiresPremium: Bool { get }
    
    // ViewBuilder to create the widget's content
    @ViewBuilder
    func build() -> any View
}

// Types of available widgets
enum WidgetType: String, Codable, CaseIterable {
    case sleepQuality = "Sleep Quality"
    case heartRate = "Heart Rate"
    case sleepDebt = "Sleep Debt"
    case environment = "Environment"
    case sleepGoals = "Sleep Goals"
    case monthlyTrend = "Monthly Trend"
    
    var systemImage: String {
        switch self {
        case .sleepQuality: return "chart.bar.fill"
        case .heartRate: return "heart.fill"
        case .sleepDebt: return "clock.fill"
        case .environment: return "thermometer"
        case .sleepGoals: return "flag.fill"
        case .monthlyTrend: return "chart.line.uptrend.xyaxis"
        }
    }
    
    var requiresPremium: Bool {
        switch self {
        case .sleepQuality, .heartRate: return false
        case .sleepDebt, .environment, .sleepGoals, .monthlyTrend: return true
        }
    }
}

// Struct to hold widget configuration
struct WidgetConfiguration: Codable {
    var id: UUID
    var type: WidgetType
    var position: Int
    var isEnabled: Bool
    
    init(type: WidgetType, position: Int, isEnabled: Bool = true) {
        self.id = UUID()
        self.type = type
        self.position = position
        self.isEnabled = isEnabled
    }
    
    // MARK: - Codable Implementation
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case position
        case isEnabled
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(WidgetType.self, forKey: .type)
        position = try container.decode(Int.self, forKey: .position)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(position, forKey: .position)
        try container.encode(isEnabled, forKey: .isEnabled)
    }
}

// MARK: - CoreData Support
extension WidgetConfiguration {
    var asDictionary: [String: Any] {
        [
            "id": id.uuidString,
            "type": type.rawValue,
            "position": position,
            "isEnabled": isEnabled
        ]
    }
    
    static func from(dictionary: [String: Any]) -> WidgetConfiguration? {
        guard let idString = dictionary["id"] as? String,
              let id = UUID(uuidString: idString),
              let typeRaw = dictionary["type"] as? String,
              let type = WidgetType(rawValue: typeRaw),
              let position = dictionary["position"] as? Int,
              let isEnabled = dictionary["isEnabled"] as? Bool else {
            return nil
        }
        
        var config = WidgetConfiguration(type: type, position: position)
        config.id = id
        config.isEnabled = isEnabled
        return config
    }
}
