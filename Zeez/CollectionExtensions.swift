import Foundation

extension Collection {
    /// Safe array access that returns nil if index is out of bounds
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}