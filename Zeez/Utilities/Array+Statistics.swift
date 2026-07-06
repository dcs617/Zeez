import Foundation
import os.log

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
        let percentileIndex = p / 100.0
        let index = Int(ceil(Double(count) * percentileIndex) - 1)
        return sorted[Swift.max(0, Swift.min(index, count - 1))]
    }
    
    func median() -> Double? {
        guard !isEmpty else { return nil }
        let sorted = self.sorted()
        
        if count % 2 == 0 {
            let middleIndex = count / 2
            return (sorted[middleIndex - 1] + sorted[middleIndex]) / 2.0
        } else {
            return sorted[count / 2]
        }
    }
    
    func weightedAverage(weights: [Double]) -> Double? {
        guard !isEmpty, weights.count == count else { return nil }
        
        let weightedSum = zip(self, weights).map { $0 * $1 }.reduce(0, +)
        let totalWeight = weights.reduce(0, +)
        
        return totalWeight > 0 ? weightedSum / totalWeight : nil
    }
}
