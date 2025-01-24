import CoreData
import Foundation

class BrainActivityAnalyzer {
    static let shared = BrainActivityAnalyzer()
    private init() {}
    
    // Maps sleep stages to their typical frequency ranges
    struct FrequencyRange {
        let min: Double
        let max: Double
        let mainAmplitude: Double
        let variability: Double
    }
    
    private let stageFrequencies: [String: FrequencyRange] = [
        "awake": FrequencyRange(min: 13, max: 30, mainAmplitude: 10, variability: 2),
        "light": FrequencyRange(min: 8, max: 13, mainAmplitude: 20, variability: 5),
        "deep": FrequencyRange(min: 0.5, max: 4, mainAmplitude: 40, variability: 10),
        "rem": FrequencyRange(min: 15, max: 25, mainAmplitude: 15, variability: 8)
    ]
    
    // Core brain activity functions
    func getCurrentSleepStage(context: NSManagedObjectContext) -> SleepStage? {
        let request: NSFetchRequest<SleepStage> = SleepStage.fetchRequest()
        request.predicate = NSPredicate(format: "startTime <= %@ AND endTime >= %@", Date() as NSDate, Date() as NSDate)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }
    
    func getLatestSleepStages(context: NSManagedObjectContext, limit: Int = 5) -> [SleepStage] {
        let request: NSFetchRequest<SleepStage> = SleepStage.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SleepStage.endTime, ascending: false)]
        request.fetchLimit = limit
        return (try? context.fetch(request)) ?? []
    }
    
    func generateBrainWaveData(for stage: String, duration: TimeInterval = 5.0) -> [(TimeInterval, Double)] {
        var waveform: [(TimeInterval, Double)] = []
        let range = stageFrequencies[stage.lowercased()] ?? stageFrequencies["light"]!
        
        // Sample rate: 20 samples per second
        let sampleRate = 0.05
        for t in stride(from: 0.0, to: duration, by: sampleRate) {
            let baseFrequency = (range.max + range.min) / 2
            let amplitude = range.mainAmplitude + range.variability * sin(t)
            
            // Generate primary wave
            let primaryWave = amplitude * sin(2 * .pi * baseFrequency * t)
            
            // Add noise and secondary frequencies for realism
            let noise = Double.random(in: -2...2)
            let secondaryWave = (amplitude * 0.3) * sin(2 * .pi * (baseFrequency * 1.5) * t)
            
            let value = primaryWave + secondaryWave + noise
            waveform.append((t, value))
        }
        
        return waveform
    }
    
    // Stage metadata functions
    func getStageInfo(_ stage: String) -> (name: String, description: String, characteristics: [String]) {
        let stageLower = stage.lowercased()
        
        switch stageLower {
        case "awake":
            return (
                "Awake",
                """
                During wakefulness, your brain exhibits primarily beta waves, indicating 
                active consciousness and alertness. This is characterized by high-frequency, 
                low-amplitude brain activity.
                """,
                [
                    "Beta waves (13-30 Hz)",
                    "High mental activity",
                    "Full muscle control",
                    "Environmental awareness"
                ]
            )
            
        case "light":
            return (
                "Light Sleep",
                """
                Light sleep is a transitional stage where your body begins preparing for 
                deeper sleep. Brain waves slow down, and sleep spindles may occur, which 
                are important for memory processing.
                """,
                [
                    "Alpha and theta waves",
                    "Decreased heart rate",
                    "Reduced body temperature",
                    "Occasional muscle twitches"
                ]
            )
            
        case "deep":
            return (
                "Deep Sleep",
                """
                Deep sleep is crucial for physical restoration and memory consolidation. 
                Your brain produces slow delta waves, and it's during this stage that 
                growth hormone is released and tissue repair occurs.
                """,
                [
                    "Delta waves (0.5-4 Hz)",
                    "Physical restoration",
                    "Immune system boost",
                    "Memory consolidation"
                ]
            )
            
        case "rem":
            return (
                "REM Sleep",
                """
                REM (Rapid Eye Movement) sleep is when most dreaming occurs. Your brain 
                becomes highly active, similar to wakefulness, while your body remains 
                in a state of temporary paralysis.
                """,
                [
                    "Mixed frequency waves",
                    "Vivid dreams",
                    "Muscle atonia",
                    "Rapid eye movements"
                ]
            )
            
        default:
            return (
                "Unknown Stage",
                "Sleep stage information not available.",
                ["No characteristics available"]
            )
        }
    }
    
    // Analysis functions
    func getStageQuality(_ stage: SleepStage) -> Double {
        let duration = stage.duration

        // Base quality on ideal durations for each stage
        switch stage.stageType?.lowercased() {
        case "light": return min(duration / 3600, 1.0) // Ideal: 1 hour
        case "deep": return min(duration / 5400, 1.0)  // Ideal: 1.5 hours
        case "rem": return min(duration / 5400, 1.0)   // Ideal: 1.5 hours
        default: return 0
        }
    }
    
    func analyzeSleepCycle(stages: [SleepStage]) -> (complete: Bool, quality: Double) {
        var hasLight = false
        var hasDeep = false
        var hasREM = false
        var totalQuality = 0.0
        
        for stage in stages {
            guard let type = stage.stageType?.lowercased() else { continue }
            
            switch type {
            case "light": hasLight = true
            case "deep": hasDeep = true
            case "rem": hasREM = true
            default: break
            }
            
            totalQuality += getStageQuality(stage)
        }
        
        let isComplete = hasLight && hasDeep && hasREM
        let averageQuality = totalQuality / Double(stages.count)
        
        return (isComplete, averageQuality)
    }
    
    // Sleep stage transition analysis
    func getStageTransitions(context: NSManagedObjectContext, hours: Int = 8) -> [(from: String, to: String, timestamp: Date)] {
        let request: NSFetchRequest<SleepStage> = SleepStage.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SleepStage.startTime, ascending: true)]
        request.predicate = NSPredicate(
            format: "startTime >= %@",
            Calendar.current.date(byAdding: .hour, value: -hours, to: Date())! as NSDate
        )
        
        guard let stages = try? context.fetch(request) else { return [] }
        
        var transitions: [(String, String, Date)] = []
        for i in 0..<stages.count-1 {
            if let fromType = stages[i].stageType,
               let toType = stages[i+1].stageType,
               let timestamp = stages[i+1].startTime {
                transitions.append((fromType, toType, timestamp))
            }
        }
        
        return transitions
    }
}
