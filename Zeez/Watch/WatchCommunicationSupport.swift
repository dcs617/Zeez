import Foundation
import WatchConnectivity
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
    let retryCount: Int
    
    init(type: WatchMessageType, data: [String: Any], priority: MessagePriority = .medium) {
        self.id = UUID()
        self.type = type
        self.data = data
        self.priority = priority
        self.timestamp = Date()
        self.retryCount = 0
    }
    
    private init(id: UUID, type: WatchMessageType, data: [String: Any], priority: MessagePriority, timestamp: Date, retryCount: Int) {
        self.id = id
        self.type = type
        self.data = data
        self.priority = priority
        self.timestamp = timestamp
        self.retryCount = retryCount
    }
    
    func withIncrementedRetry() -> WatchMessage {
        return WatchMessage(
            id: self.id,
            type: self.type,
            data: self.data,
            priority: self.priority,
            timestamp: self.timestamp,
            retryCount: self.retryCount + 1
        )
    }
    
    func toDictionary() throws -> [String: Any] {
        var dict = data
        dict["messageId"] = id.uuidString
        dict["command"] = type.rawValue
        dict["priority"] = priority.rawValue
        dict["timestamp"] = timestamp.timeIntervalSince1970
        dict["retryCount"] = retryCount
        return dict
    }
}

// MARK: - Extended Message Types
// WatchMessageType, HapticPattern, WakePatternData and the watch display
// models are defined once in Shared/WatchDataModels.swift (both targets).

extension WatchMessageType {
    static let heartbeat = WatchMessageType.requestData // Reuse existing for compatibility
    static let statusUpdate = WatchMessageType.requestData
    static let dataSync = WatchMessageType.sleepSummary
    static let error = WatchMessageType.requestData
}

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
    
    func markForRetry(_ message: WatchMessage) {
        queue.async(flags: .barrier) {
            if let index = self.pendingMessages.firstIndex(where: { $0.id == message.id }) {
                self.pendingMessages[index] = message.withIncrementedRetry()
            }
        }
    }
    
    func retryFailedMessages(using sender: @escaping (WatchMessage) -> Void) {
        queue.async(flags: .barrier) {
            let messagesToRetry = self.pendingMessages.filter { message in
                message.retryCount > 0 && Date().timeIntervalSince(message.timestamp) > 30
            }
            
            for message in messagesToRetry {
                DispatchQueue.main.async {
                    sender(message)
                }
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

// MARK: - Retry Manager

class RetryManager {
    private let maxRetries: Int = 3
    private let retryDelays: [TimeInterval] = [1, 5, 15] // Progressive delays
    
    func shouldRetry(_ message: WatchMessage, error: Error) -> Bool {
        // Don't retry if we've exceeded max attempts
        guard message.retryCount < maxRetries else { return false }
        
        // Check if error is retryable
        if let wcError = error as? WCError {
            switch wcError.code {
            case .sessionNotActivated, .watchAppNotInstalled, .notReachable:
                return true // These might be temporary
            case .invalidParameter, .payloadTooLarge:
                return false // These won't resolve with retries
            default:
                return true
            }
        }
        
        return true // Retry unknown errors
    }
    
    func getRetryDelay(for retryCount: Int) -> TimeInterval {
        let index = min(retryCount, retryDelays.count - 1)
        return retryDelays[index]
    }
}

// MARK: - Data Compression

class WatchDataCompression {
    private let compressionThreshold = 1024 // 1KB
    
    func compressIfNeeded(_ data: [String: Any]) -> [String: Any] {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data)
            
            guard jsonData.count > compressionThreshold else {
                return data // Don't compress small payloads
            }
            
            let compressedData = try (jsonData as NSData).compressed(using: .lzfse)
            
            // If compression doesn't save enough space, use original
            guard compressedData.count < Int(Double(jsonData.count) * 0.8) else {
                return data
            }
            
            return [
                "_compressed": true,
                "_data": compressedData.base64EncodedString(),
                "_originalSize": jsonData.count
            ]
            
        } catch {
            ZeezLogger.error(ZeezLogger.network, "Failed to compress watch data", error: error)
            return data
        }
    }
    
    func decompressIfNeeded(_ data: [String: Any]) -> [String: Any] {
        guard let isCompressed = data["_compressed"] as? Bool, isCompressed,
              let compressedString = data["_data"] as? String,
              let compressedData = Data(base64Encoded: compressedString) else {
            return data // Not compressed
        }
        
        do {
            let decompressedData = try (compressedData as NSData).decompressed(using: .lzfse) as Data
            let decompressedDict = try JSONSerialization.jsonObject(with: decompressedData) as? [String: Any]
            
            return decompressedDict ?? data
            
        } catch {
            ZeezLogger.error(ZeezLogger.network, "Failed to decompress watch data", error: error)
            return data
        }
    }
}

// MARK: - Sync Coordinator

class WatchSyncCoordinator {
    private var lastSyncTime: Date?
    private let syncInterval: TimeInterval = 300 // 5 minutes
    private var pendingSyncTypes: Set<WatchMessageType> = []
    
    func shouldSync(_ type: WatchMessageType) -> Bool {
        // Always sync high-priority messages
        if isHighPriority(type) {
            return true
        }
        
        // Check if enough time has passed for regular sync
        guard let lastSync = lastSyncTime else {
            return true // First sync
        }
        
        return Date().timeIntervalSince(lastSync) >= syncInterval
    }
    
    func markSyncCompleted(for type: WatchMessageType) {
        lastSyncTime = Date()
        pendingSyncTypes.remove(type)
    }
    
    func addPendingSync(for type: WatchMessageType) {
        pendingSyncTypes.insert(type)
    }
    
    func getPendingSyncTypes() -> Set<WatchMessageType> {
        return pendingSyncTypes
    }
    
    private func isHighPriority(_ type: WatchMessageType) -> Bool {
        switch type {
        case .wakePattern, .stopPattern, .acknowledge, .snooze:
            return true
        default:
            return false
        }
    }
}

