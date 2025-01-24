import SwiftUI

enum DataSource: String {
    case healthKit = "HealthKit"
    case manual = "Manual"
    case watch = "Apple Watch"
    
    var icon: String {
        switch self {
        case .healthKit: return "heart.fill"
        case .manual: return "hand.draw.fill"
        case .watch: return "applewatch"
        }
    }
    
    var color: Color {
        switch self {
        case .healthKit: return .green
        case .manual: return .blue
        case .watch: return .purple
        }
    }
}

struct DataSourceBadge: View {
    let source: DataSource
    let size: BadgeSize
    
    enum BadgeSize {
        case small, medium, large
        
        var iconSize: CGFloat {
            switch self {
            case .small: return 8
            case .medium: return 12
            case .large: return 16
            }
        }
        
        var padding: CGFloat {
            switch self {
            case .small: return 4
            case .medium: return 6
            case .large: return 8
            }
        }
        
        var fontSize: CGFloat {
            switch self {
            case .small: return 8
            case .medium: return 10
            case .large: return 12
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: source.icon)
                .font(.system(size: size.iconSize))
            
            if size != .small {
                Text(source.rawValue)
                    .font(.system(size: size.fontSize))
            }
        }
        .padding(size.padding)
        .foregroundColor(.white)
        .background(source.color)
        .cornerRadius(size.padding * 2)
    }
}

struct DataSourceIndicator: View {
    let sources: [DataSource]
    let size: DataSourceBadge.BadgeSize
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(sources, id: \.rawValue) { source in
                DataSourceBadge(source: source, size: size)
            }
        }
    }
}
