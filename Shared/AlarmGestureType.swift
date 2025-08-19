import Foundation

/// Represents different types of gestures that can be used to interact with alarms
public enum AlarmGestureType: String, CaseIterable {
    case tap = "tap"
    case doubleTap = "double_tap"
    case longPress = "long_press"
    case shake = "shake"
    case flip = "flip"
    case math = "math"
    case type = "type"
    case pattern = "pattern"
    
    public var displayName: String {
        switch self {
        case .tap:
            return "Single Tap"
        case .doubleTap:
            return "Double Tap"
        case .longPress:
            return "Long Press"
        case .shake:
            return "Shake Device"
        case .flip:
            return "Flip Device"
        case .math:
            return "Solve Math Problem"
        case .type:
            return "Type Phrase"
        case .pattern:
            return "Draw Pattern"
        }
    }
    
    public var description: String {
        switch self {
        case .tap:
            return "Tap once to confirm"
        case .doubleTap:
            return "Double tap quickly to confirm"
        case .longPress:
            return "Press and hold for 2 seconds"
        case .shake:
            return "Shake your device vigorously"
        case .flip:
            return "Turn your device face down"
        case .math:
            return "Solve a simple math problem"
        case .type:
            return "Type the phrase exactly"
        case .pattern:
            return "Draw the specified pattern"
        }
    }
    
    public var requiresFullApp: Bool {
        switch self {
        case .math, .type, .pattern:
            return true
        default:
            return false
        }
    }
    
    public var requiresMotion: Bool {
        switch self {
        case .shake, .flip:
            return true
        default:
            return false
        }
    }
    
    public var requiresKeyboard: Bool {
        switch self {
        case .math, .type:
            return true
        default:
            return false
        }
    }
}
