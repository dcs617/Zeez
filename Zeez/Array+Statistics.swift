import Foundation

extension Array where Element == Double {
    var average: Double? {
        guard !isEmpty else { return nil }
        return reduce(0, +) / Double(count)
    }
    
    var variance: Double? {
        guard let avg = average, count > 1 else { return nil }
        let squaredDifferences = map { pow($0 - avg, 2) }
        return squaredDifferences.reduce(0, +) / Double(count - 1)
    }
    
    var standardDeviation: Double? {
        guard let variance = variance else { return nil }
        return sqrt(variance)
    }
    
    func percentile(_ p: Double) -> Double? {
        guard !isEmpty else { return nil }
        let sorted = self.sorted()
        let index = Int(ceil(Double(count) * p) - 1)
        return sorted[Swift.max(0, Swift.min(index, count - 1))]
    }
}
