import Foundation
import SwiftUI

extension HeartRateView {
    func calculateStats(data: [HeartRateData]) -> DetailedHeartRateStats {
        let values = data.map { $0.value }
        let average = values.reduce(0, +) / Double(values.count)
        
        // Calculate resting heart rate (average of lowest 20% of readings)
        let sortedValues = values.sorted()
        let restingCount = max(1, Int(Double(values.count) * 0.2))
        let restingValues = Array(sortedValues.prefix(restingCount))
        let resting = restingValues.reduce(0, +) / Double(restingValues.count)
        
        return DetailedHeartRateStats(
            average: Int(average),
            averageTrend: TrendDirection.neutral,
            resting: Int(resting),
            restingTrend: TrendDirection.down,
            minimum: Int(values.min() ?? 0),
            maximum: Int(values.max() ?? 0)
        )
    }
    
    func formatHeartRateData(_ data: [HeartRateData]) -> [HeartRateDataPoint] {
        let filteredData: [HeartRateData]
        let now = Date()
        
        switch self.selectedTimeRange {
        case .hour:
            let hourAgo = now.addingTimeInterval(-3600)
            filteredData = data.filter { $0.timestamp?.timeIntervalSince(hourAgo) ?? 0 >= 0 }
        case .threeHours:
            let threeHoursAgo = now.addingTimeInterval(-10800)
            filteredData = data.filter { $0.timestamp?.timeIntervalSince(threeHoursAgo) ?? 0 >= 0 }
        case .all:
            filteredData = data
        }
        
        return filteredData.compactMap { hrData in
            guard let timestamp = hrData.timestamp else { return nil }
            return HeartRateDataPoint(
                date: timestamp,
                value: hrData.value,
                confidence: hrData.confidence
            )
        }.sorted { $0.date < $1.date }
    }
    
    func calculateHeartRateZones(data: [HeartRateData]) -> [HeartRateZone] {
        let values = data.map { $0.value }
        let total = Double(values.count)
        
        let zones = [
            ("Rest", 40...60, Color.green),
            ("Light", 61...90, Color.blue),
            ("Moderate", 91...110, Color.yellow),
            ("Elevated", 111...130, Color.orange),
            ("High", 131...200, Color.red)
        ]
        
        return zones.enumerated().map { index, zone in
            let count = values.filter { zone.1.contains(Int($0)) }.count
            let percentage = (Double(count) / total) * 100
            
            return HeartRateZone(
                id: index,
                name: zone.0,
                range: "\(zone.1.lowerBound)-\(zone.1.upperBound)",
                percentage: percentage,
                color: zone.2
            )
        }
    }
    
    func calculateHRV(data: [HeartRateData]) -> HRVData {
        // Simplified HRV calculation using RMSSD method
        let values = data.map { $0.value }
        var differences: [Double] = []
        
        for i in 0..<values.count-1 {
            differences.append(abs(values[i] - values[i+1]))
        }
        
        let squaredDiffs = differences.map { pow($0, 2) }
        let mean = squaredDiffs.reduce(0, +) / Double(squaredDiffs.count)
        let rmssd = sqrt(mean)
        
        let timeData: [HRVDataPoint] = data.enumerated().compactMap { index, hrData in
            guard index < differences.count,
                  let timestamp = hrData.timestamp else { return nil }
            return HRVDataPoint(
                date: timestamp,
                value: differences[index]
            )
        }
        
        let quality: HRVQuality = switch rmssd {
        case 0...20: .poor
        case 20...50: .fair
        case 50...100: .good
        default: .excellent
        }
        
        return HRVData(
            average: rmssd,
            quality: quality,
            timeData: timeData
        )
    }
    
    func calculateStageCorrelation(heartRateData: [HeartRateData], stages: [SleepStage]) -> [StageCorrelation] {
        let stageColors: [String: Color] = [
            "LIGHT": .blue,
            "DEEP": .indigo,
            "REM": .purple,
            "AWAKE": .orange
        ]
        
        return stages.compactMap { stage in
            guard let stageName = stage.stageType,
                  let stageStart = stage.startTime,
                  let stageEnd = stage.endTime else { return nil }
            
            let stageHRData = heartRateData.filter { hrData in
                guard let timestamp = hrData.timestamp else { return false }
                return timestamp >= stageStart && timestamp <= stageEnd
            }
            
            guard !stageHRData.isEmpty else { return nil }
            
            let averageHR = stageHRData.map(\.value).reduce(0, +) / Double(stageHRData.count)
            
            return StageCorrelation(
                stageName: stageName,
                averageHR: Int(averageHR),
                timeSpent: stage.duration,
                color: stageColors[stageName] ?? .gray
            )
        }
    }
}
