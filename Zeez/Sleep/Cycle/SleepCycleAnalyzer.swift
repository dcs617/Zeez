import Foundation
import CoreData
import SwiftUI
import os.log

struct CycleAnalysis {
    let cycleCount: Int
    let completedCycles: Int
    let averageDuration: TimeInterval
    let consistency: Double
    let quality: Double
    let idealCycles: [IdealCycle]
    let insights: [CycleInsight]
    let personalizedCycleLength: TimeInterval
    let confidence: Double
}

struct CycleInsight {
    let title: String
    let message: String
    let icon: String
    let color: Color
}

class SleepCycleAnalyzer {
    private let session: SleepSession
    private let context: NSManagedObjectContext
    private var cycleLength: TimeInterval = AppConstants.SleepCycle.standardLength // Will be personalized
    private let personalizationManager = PersonalizationManager.shared
    
    init(session: SleepSession, context: NSManagedObjectContext) {
        self.session = session
        self.context = context
    }
    
    func analyzeCycles() async -> CycleAnalysis {
        // Get personalized cycle length for this user
        do {
            let personalizedLength = try await personalizationManager.calculatePersonalizedCycleLength()
            cycleLength = personalizedLength
            ZeezLogger.sleepTracking.info("Using personalized cycle length: \(personalizedLength / 60) minutes")
        } catch {
            ZeezLogger.sleepTracking.error("Failed to get personalized cycle length: \(error.localizedDescription)")
            // Fall back to standard length
        }
        
        let stages = session.sleepStages?.allObjects as? [SleepStage] ?? []
        let sortedStages = stages.sorted { ($0.startTime ?? Date()) < ($1.startTime ?? Date()) }
        
        let cycles = identifyCycles(stages: sortedStages)
        let completedCycles = countCompletedCycles(cycles)
        let consistency = calculateConsistency(cycles)
        let quality = calculateQuality(cycles)
        let idealCycles = generateIdealCycles()
        let confidence = await calculateAnalysisConfidence()
        let insights = generateInsights(
            cycleCount: cycles.count,
            completedCycles: completedCycles,
            consistency: consistency,
            quality: quality,
            confidence: confidence
        )
        
        return CycleAnalysis(
            cycleCount: cycles.count,
            completedCycles: completedCycles,
            averageDuration: calculateAverageDuration(cycles),
            consistency: consistency,
            quality: quality,
            idealCycles: idealCycles,
            insights: insights,
            personalizedCycleLength: cycleLength,
            confidence: confidence
        )
    }
    
    // MARK: - Cycle Identification
    
    private func identifyCycles(stages: [SleepStage]) -> [[SleepStage]] {
        var cycles: [[SleepStage]] = []
        var currentCycle: [SleepStage] = []
        var previousType: String?
        
        for stage in stages {
            guard let currentType = stage.stageType else { continue }
            
            // Check for cycle transition conditions
            if shouldStartNewCycle(previousType: previousType, currentType: currentType) {
                if !currentCycle.isEmpty {
                    cycles.append(currentCycle)
                }
                currentCycle = []
            }
            
            currentCycle.append(stage)
            previousType = currentType
        }
        
        // Add the last cycle
        if !currentCycle.isEmpty {
            cycles.append(currentCycle)
        }
        
        return cycles
    }
    
    private func shouldStartNewCycle(previousType: String?, currentType: String) -> Bool {
        // A new cycle typically starts when:
        // 1. Moving from REM to Light Sleep
        // 2. Moving from any stage to Light Sleep after being in Deep Sleep
        guard let previous = previousType else { return false }
        
        if previous == "REM" && currentType == "LIGHT" {
            return true
        }
        
        if previous == "DEEP" && currentType == "LIGHT" {
            return true
        }
        
        return false
    }
    
    // MARK: - Quality Metrics
    
    private func countCompletedCycles(_ cycles: [[SleepStage]]) -> Int {
        cycles.filter { cycle in
            let stageTypes = Set(cycle.compactMap { $0.stageType })
            // A complete cycle should have Light, Deep, and REM stages
            return stageTypes.contains("LIGHT") &&
                   stageTypes.contains("DEEP") &&
                   stageTypes.contains("REM")
        }.count
    }
    
    private func calculateConsistency(_ cycles: [[SleepStage]]) -> Double {
        guard cycles.count > 1 else { return 100 }
        
        let durations = cycles.map { cycle in
            cycle.reduce(0.0) { $0 + $1.duration }
        }
        
        let avgDuration = durations.reduce(0, +) / Double(durations.count)
        let variance = durations.map { pow($0 - avgDuration, 2) }.reduce(0, +) / Double(durations.count)
        let stdDev = sqrt(variance)
        
        // Convert to a percentage score (lower deviation = higher consistency)
        let maxAllowedDeviation: TimeInterval = AppConstants.SleepCycle.maxDeviation // 30 minutes
        let consistency = 100 * (1 - min(stdDev / maxAllowedDeviation, 1))
        
        return max(0, min(100, consistency))
    }
    
    private func calculateQuality(_ cycles: [[SleepStage]]) -> Double {
        let weights: [Double] = [0.4, 0.3, 0.3] // Completeness, Consistency, Timing
        
        let completeness = Double(countCompletedCycles(cycles)) / Double(max(1, cycles.count)) * 100
        let consistency = calculateConsistency(cycles)
        let timing = calculateTimingQuality()
        
        let weightedScores = [
            completeness * weights[0],
            consistency * weights[1],
            timing * weights[2]
        ]
        
        return weightedScores.reduce(0, +)
    }
    
    private func calculateTimingQuality() -> Double {
        guard let startTime = session.startTime else { return 0 }
        
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: startTime)
        
        switch hour {
        case 21...22: return 100 // Optimal bedtime
        case 20, 23: return 80  // Good bedtime
        case 19, 0: return 60   // Fair bedtime
        default: return 40      // Suboptimal bedtime
        }
    }
    
    private func calculateAverageDuration(_ cycles: [[SleepStage]]) -> TimeInterval {
        guard !cycles.isEmpty else { return 0 }
        
        let totalDuration = cycles.reduce(0.0) { sum, cycle in
            sum + cycle.reduce(0.0) { $0 + $1.duration }
        }
        
        return totalDuration / Double(cycles.count)
    }
    
    private func generateIdealCycles() -> [IdealCycle] {
        guard let startTime = session.startTime,
              let endTime = session.endTime else { return [] }
        
        var idealCycles: [IdealCycle] = []
        var currentTime = startTime
        
        while currentTime < endTime {
            // Each stage in the ideal 90-minute cycle
            idealCycles.append(contentsOf: [
                IdealCycle(time: currentTime, stageValue: 1),                              // Light sleep
                IdealCycle(time: currentTime.addingTimeInterval(AppConstants.SleepCycle.IdealTiming.deepSleepOnset), stageValue: 0),  // Deep sleep after 20m
                IdealCycle(time: currentTime.addingTimeInterval(AppConstants.SleepCycle.IdealTiming.lightSleepReturn), stageValue: 1),  // Back to light after 45m
                IdealCycle(time: currentTime.addingTimeInterval(AppConstants.SleepCycle.IdealTiming.remOnset), stageValue: 2),  // REM after 60m
                IdealCycle(time: currentTime.addingTimeInterval(AppConstants.SleepCycle.IdealTiming.cycleCompletion), stageValue: 1)   // Back to light after 85m
            ])
            
            currentTime = currentTime.addingTimeInterval(cycleLength)
        }
        
        return idealCycles
    }
    
    private func generateInsights(cycleCount: Int, completedCycles: Int,
                                consistency: Double, quality: Double, confidence: Double) -> [CycleInsight] {
        var insights: [CycleInsight] = []
        
        // Cycle completion insight
        if completedCycles > 0 {
            let completionRatio = Double(completedCycles) / Double(cycleCount)
            if completionRatio >= 0.8 {
                insights.append(CycleInsight(
                    title: "Excellent Cycle Completion",
                    message: "Most of your sleep cycles were complete, indicating restorative sleep",
                    icon: "checkmark.circle.fill",
                    color: .green
                ))
            } else if completionRatio >= 0.6 {
                insights.append(CycleInsight(
                    title: "Good Cycle Completion",
                    message: "Many of your sleep cycles were complete, but there's room for improvement",
                    icon: "checkmark.circle",
                    color: .blue
                ))
            }
        }
        
        // Consistency insight
        if consistency >= 90 {
            insights.append(CycleInsight(
                title: "Consistent Cycles",
                message: "Your sleep cycles show excellent regularity",
                icon: "clock.fill",
                color: .green
            ))
        } else if consistency >= 70 {
            insights.append(CycleInsight(
                title: "Fairly Regular Cycles",
                message: "Your sleep cycles are moderately consistent",
                icon: "clock",
                color: .blue
            ))
        }
        
        // Overall quality insight
        if quality >= 90 {
            insights.append(CycleInsight(
                title: "Outstanding Sleep Quality",
                message: "Your sleep cycles indicate highly restorative sleep",
                icon: "star.fill",
                color: .green
            ))
        } else if quality >= 70 {
            insights.append(CycleInsight(
                title: "Good Sleep Quality",
                message: "Your sleep patterns suggest good quality rest",
                icon: "star",
                color: .blue
            ))
        }
        
        // Add personalization insights
        if confidence >= 75 {
            insights.append(CycleInsight(
                title: "Personalized Analysis",
                message: "Analysis uses your personal sleep patterns for higher accuracy",
                icon: "person.fill",
                color: .purple
            ))
        }
        
        // Add cycle length personalization insight
        let standardLength = AppConstants.SleepCycle.standardLength
        if abs(cycleLength - standardLength) > 300 { // 5 minutes difference
            let difference = (cycleLength - standardLength) / 60
            let direction = difference > 0 ? "longer" : "shorter"
            insights.append(CycleInsight(
                title: "Personalized Cycle Length",
                message: "Your cycles are \(String(format: "%.0f", abs(difference))) minutes \(direction) than average",
                icon: "chart.line.uptrend.xyaxis",
                color: .orange
            ))
        }
        
        return insights
    }
    
    // MARK: - Confidence Calculation
    
    private func calculateAnalysisConfidence() async -> Double {
        do {
            let confidence = try await personalizationManager.calculateConfidenceScore(for: session)
            return confidence.overallScore
        } catch {
            ZeezLogger.sleepTracking.error("Failed to calculate confidence score: \(error.localizedDescription)")
            return 50.0 // Default moderate confidence
        }
    }
}
