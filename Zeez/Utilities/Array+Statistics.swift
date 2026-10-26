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

    /// Sample variance of values that wrap around at `period`, such as clock times in seconds
    /// since midnight (`period` 86 400). Each value is measured from the circular mean along
    /// the shorter way round, so 23:50 and 00:10 are 20 minutes apart, not 23 h 40 min.
    func circularVariance(period: Double) -> Double? {
        guard count > 1, period > 0 else { return nil }
        let angles = map { $0 / period * 2 * Double.pi }
        let meanAngle = atan2(angles.map { sin($0) }.reduce(0, +), angles.map { cos($0) }.reduce(0, +))
        let deviations = angles.map { remainder($0 - meanAngle, 2 * Double.pi) / (2 * Double.pi) * period }
        return deviations.map { $0 * $0 }.reduce(0, +) / Double(count - 1)
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
