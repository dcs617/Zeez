import Foundation
import os.log

// MARK: - Watch Message System

// MARK: - Message Priority

enum MessagePriority: Int {
    case low = 0
    case medium = 1
    case high = 2
}

// MARK: - Watch Message

struct WatchMessage {
    let id: UUID
    let type: WatchMessageType
    let data: [String: Any]
    let priority: MessagePriority
    let timestamp: Date
    
    init(type: WatchMessageType, data: [String: Any], priority: MessagePriority = .medium) {
        self.id = UUID()
        self.type = type
        self.data = data
        self.priority = priority
        self.timestamp = Date()
    }
    
    func toDictionary() throws -> [String: Any] {
        var dict = data
        dict["messageId"] = id.uuidString
        dict["command"] = type.rawValue
        dict["priority"] = priority.rawValue
        dict["timestamp"] = timestamp.timeIntervalSince1970
        return dict
    }
}

// WatchMessageType, HapticPattern, WakePatternData and the watch display
// models are defined once in Shared/WatchDataModels.swift (both targets).

// MARK: - Message Queue

class WatchMessageQueue {
    private var pendingMessages: [WatchMessage] = []
    private var completedMessages: [WatchMessage] = []
    private var failedMessages: [WatchMessage] = []
    private let queue = DispatchQueue(label: "com.zeez.watchMessageQueue", attributes: .concurrent)
    
    var pendingCount: Int {
        return queue.sync { pendingMessages.count }
    }
    
    func enqueue(_ message: WatchMessage) {
        queue.async(flags: .barrier) {
            self.pendingMessages.append(message)
        }
    }
    
    func markAsCompleted(_ message: WatchMessage) {
        queue.async(flags: .barrier) {
            self.pendingMessages.removeAll { $0.id == message.id }
            self.completedMessages.append(message)
            
            // Keep only recent completed messages
            if self.completedMessages.count > 100 {
                self.completedMessages.removeFirst(50)
            }
        }
    }
    
    func markAsFailed(_ message: WatchMessage) {
        queue.async(flags: .barrier) {
            self.pendingMessages.removeAll { $0.id == message.id }
            self.failedMessages.append(message)
            
            // Keep only recent failed messages
            if self.failedMessages.count > 50 {
                self.failedMessages.removeFirst(25)
            }
        }
    }
    
    func clear() {
        queue.async(flags: .barrier) {
            self.pendingMessages.removeAll()
        }
    }
    
    func getStatistics() -> [String: Int] {
        return queue.sync {
            return [
                "pending": pendingMessages.count,
                "completed": completedMessages.count,
                "failed": failedMessages.count
            ]
        }
    }
}
