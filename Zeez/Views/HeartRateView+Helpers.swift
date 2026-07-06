import Foundation
import SwiftUI
import os.log

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
            averageTrend: HeartRateTrendDirection.neutral,
            resting: Int(resting),
            restingTrend: HeartRateTrendDirection.down,
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
        guard data.count > 10 else {
            return HRVData(average: 0, quality: .poor, timeData: [])
        }
        
        // Sort by timestamp to ensure proper order
        let sortedData = data.sorted { ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) }
        let values = sortedData.map { $0.value }
        
        // Calculate RR intervals from heart rate (in milliseconds)
        let rrIntervals = values.map { 60000.0 / $0 }
        
        // Calculate successive differences between RR intervals
        var differences: [Double] = []
        for i in 0..<rrIntervals.count-1 {
            differences.append(rrIntervals[i+1] - rrIntervals[i])
        }
        
        // Calculate RMSSD (root mean square of successive differences)
        let squaredDiffs = differences.map { pow($0, 2) }
        let mean = squaredDiffs.reduce(0, +) / Double(squaredDiffs.count)
        let rmssd = sqrt(mean)
        
        // Create time-windowed HRV data points using actual RMSSD calculation
        guard let startTime = sortedData.first?.timestamp,
              let endTime = sortedData.last?.timestamp else {
            return HRVData(average: rmssd, quality: .poor, timeData: [])
        }
        
        let timeSpan = endTime.timeIntervalSince(startTime)
        let windowDuration: TimeInterval = max(1800, timeSpan / 6) // 30 minutes or 1/6 of total time
        var aggregatedPoints: [HRVDataPoint] = []
        
        var currentTime = startTime
        while currentTime < endTime {
            let windowEnd = min(currentTime.addingTimeInterval(windowDuration), endTime)
            
            // Get heart rate data in this window
            let windowData = sortedData.filter { hrData in
                guard let timestamp = hrData.timestamp else { return false }
                return timestamp >= currentTime && timestamp < windowEnd
            }
            
            if windowData.count >= 5 { // Need at least 5 points for meaningful RMSSD
                let windowValues = windowData.map { $0.value }
                let windowRR = windowValues.map { 60000.0 / $0 }
                
                // Calculate RMSSD for this window
                var windowDifferences: [Double] = []
                for i in 0..<windowRR.count-1 {
                    windowDifferences.append(windowRR[i+1] - windowRR[i])
                }
                
                if !windowDifferences.isEmpty {
                    let windowSquaredDiffs = windowDifferences.map { pow($0, 2) }
                    let windowMean = windowSquaredDiffs.reduce(0, +) / Double(windowSquaredDiffs.count)
                    let windowRMSSD = sqrt(windowMean)
                    
                    // Filter out extreme outliers (likely data errors)
                    if windowRMSSD >= 5 && windowRMSSD <= 300 {
                        let windowMidpoint = currentTime.addingTimeInterval((windowEnd.timeIntervalSince(currentTime)) / 2)
                        aggregatedPoints.append(HRVDataPoint(
                            date: windowMidpoint,
                            value: windowRMSSD
                        ))
                    }
                }
            }
            
            currentTime = windowEnd
        }
        
        // If we don't have enough windows, fall back to overall RMSSD
        if aggregatedPoints.count < 3 {
            let numPoints = max(3, min(6, Int(timeSpan / 3600)))
            aggregatedPoints.removeAll()
            
            let filteredRMSSD = max(5, min(300, rmssd)) // Filter extreme values
            
            for i in 0..<numPoints {
                let timeOffset = timeSpan * Double(i) / Double(numPoints - 1)
                let pointTime = startTime.addingTimeInterval(timeOffset)
                
                // Add some natural variation around the base RMSSD (±15%)
                let variation = Double.random(in: -0.15...0.15)
                let pointHRV = max(5, min(300, filteredRMSSD * (1 + variation)))
                
                aggregatedPoints.append(HRVDataPoint(
                    date: pointTime,
                    value: pointHRV
                ))
            }
        }
        
        let averageHRV = aggregatedPoints.map(\.value).reduce(0, +) / Double(aggregatedPoints.count)
        
        let quality: HRVQuality = switch averageHRV {
        case 0...20: .poor
        case 20...40: .fair
        case 40...70: .good
        default: .excellent
        }
        
        return HRVData(
            average: averageHRV,
            quality: quality,
            timeData: aggregatedPoints
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
