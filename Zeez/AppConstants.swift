import Foundation

/// Centralized configuration constants for the Zeez application
/// Replaces magic numbers throughout the codebase for better maintainability
struct AppConstants {
    
    // MARK: - UI Timing Constants
    
    /// UI interaction and animation timing values
    struct UI {
        /// Default delay for async UI operations (.now() + 0.5)
        static let defaultDelay: TimeInterval = 0.5
        
        /// Brief delay for animation coordination (.now() + 0.1)  
        static let briefDelay: TimeInterval = 0.1
        
        /// Standard notification display duration (.now() + 2)
        static let notificationDuration: TimeInterval = 2.0
        
        /// Extended notification display duration (.now() + 3)
        static let extendedNotificationDuration: TimeInterval = 3.0
    }
    
    // MARK: - Background Task Constants
    
    /// Background task scheduling and timing configuration
    struct Background {
        /// Sleep update task interval (15 * 60 = 15 minutes)
        static let sleepUpdateInterval: TimeInterval = 15 * 60
        
        /// Data processing task interval (60 * 60 = 1 hour)
        static let dataProcessingInterval: TimeInterval = 60 * 60
        
        /// Critical battery level threshold (0.2 = 20%)
        static let criticalBatteryLevel: Float = 0.2
        
        /// Minimum storage space threshold (100MB)
        static let minimumStorageBytes: Int64 = 100_000_000
    }
    
    // MARK: - Sleep Analysis Constants
    
    /// Sleep session validation and analysis parameters
    struct Sleep {
        /// Minimum valid sleep duration (4 * 3600 = 4 hours)
        static let minimumDuration: TimeInterval = 4 * 3600
        
        /// Maximum valid sleep duration (12 * 3600 = 12 hours)
        static let maximumDuration: TimeInterval = 12 * 3600
        
        /// Maximum session duration before validation error (24 * 3600 = 24 hours)
        static let maximumSessionDuration: TimeInterval = 24 * 3600
        
        /// Target sleep duration for analysis (8 * 3600 = 8 hours)
        static let targetDuration: TimeInterval = 8 * 3600
        
        /// Maximum sleep time variance for consistency calculation (2 * 3600 = 2 hours)
        static let maxConsistencyVariance: TimeInterval = 2 * 3600
        
        /// Recommended sleep hours for chart scaling (12 * 3600 = 12 hours)
        static let chartMaxHours: TimeInterval = 12 * 3600
        
        /// Minimum sleep time for quality warnings (7 * 3600 = 7 hours)
        static let qualityWarningThreshold: TimeInterval = 7 * 3600
        
        /// Default REM latency fallback (25 * 60 = 25 minutes)
        static let defaultREMLatency: TimeInterval = 25 * 60
    }
    
    // MARK: - Sleep Cycle Constants
    
    /// Sleep cycle analysis parameters
    struct SleepCycle {
        /// Standard sleep cycle length (90 * 60 = 90 minutes)
        static let standardLength: TimeInterval = 90 * 60
        
        /// Maximum allowed cycle deviation (30 * 60 = 30 minutes)
        static let maxDeviation: TimeInterval = 30 * 60
        
        /// Sleep stage analysis interval (30 * 60 = 30 minutes)
        static let stageAnalysisInterval: TimeInterval = 30 * 60
        
        /// Sleep analysis epoch duration (30 * 60 = 30 minutes)
        static let epochDuration: TimeInterval = 30 * 60
        
        /// Chart axis stride interval (3600 * 3 = 3 hours)
        static let chartAxisStride: TimeInterval = 3600 * 3
        
        // Ideal cycle timing for pattern analysis
        struct IdealTiming {
            /// Deep sleep onset after sleep start (20 * 60 = 20 minutes)
            static let deepSleepOnset: TimeInterval = 20 * 60
            
            /// Return to light sleep (45 * 60 = 45 minutes)
            static let lightSleepReturn: TimeInterval = 45 * 60
            
            /// REM sleep onset (60 * 60 = 60 minutes)
            static let remOnset: TimeInterval = 60 * 60
            
            /// Cycle completion time (85 * 60 = 85 minutes)
            static let cycleCompletion: TimeInterval = 85 * 60
        }
    }
    
    // MARK: - Health Data Validation Constants
    
    /// Health metrics validation ranges
    struct HealthMetrics {
        /// Heart rate validation range during sleep
        struct HeartRate {
            /// Minimum valid heart rate during sleep (45 BPM)
            static let minimumSleep: Double = 45
            
            /// Maximum valid heart rate during sleep (75 BPM)
            static let maximumSleep: Double = 75
        }
        
        /// Environmental conditions validation ranges
        struct Environmental {
            /// Minimum comfortable temperature (18°C)
            static let minimumTemperature: Double = 18
            
            /// Maximum comfortable temperature (24°C)
            static let maximumTemperature: Double = 24
            
            /// Minimum noise level (20 dB)
            static let minimumNoiseLevel: Double = 20
            
            /// Maximum acceptable noise level (50 dB)
            static let maximumNoiseLevel: Double = 50
        }
        
        /// Respiratory metrics validation
        struct Respiratory {
            /// Minimum oxygen saturation (95%)
            static let minimumOxygenSaturation: Double = 95
            
            /// Maximum oxygen saturation (100%)
            static let maximumOxygenSaturation: Double = 100
        }
    }
    
    // MARK: - Data Generation Constants
    
    /// Mock data generation parameters
    struct MockData {
        /// Default mock data generation period (90 days)
        static let defaultGenerationDays: Int = 90
        
        /// Test data generation period (7 days)
        static let testGenerationDays: Int = 7
        
        /// Preview data generation period (1 day)
        static let previewGenerationDays: Int = 1
        
        /// Dashboard debug data period (10 days)
        static let debugGenerationDays: Int = 10
        
        /// Sleep stage data interval (15 * 60 = 15 minutes)
        static let sleepStageInterval: TimeInterval = 15 * 60
        
        /// Heart rate data interval (5 * 60 = 5 minutes)
        static let heartRateInterval: TimeInterval = 5 * 60
        
        /// Movement data interval (60 seconds = 1 minute)
        static let movementInterval: TimeInterval = 60
        
        /// Environmental data interval (5 * 60 = 5 minutes)
        static let environmentalInterval: TimeInterval = 5 * 60
    }
    
    // MARK: - Learning System Constants
    
    /// Educational content and progress tracking
    struct Learning {
        /// Article reading progress threshold (70% of estimated read time)
        static let readingProgressThreshold: Double = 0.7
        
        /// Daily fact notification delay (24 * 60 * 60 = 24 hours)
        static let dailyFactInterval: TimeInterval = 24 * 60 * 60
        
        /// Achievement notification trigger delay (60 * 60 = 1 hour)
        static let achievementNotificationDelay: TimeInterval = 60 * 60
    }
    
    // MARK: - Chart and Visualization Constants
    
    /// Data visualization parameters
    struct Charts {
        /// Historical trend chart period (86400 = 1 day in seconds)
        static let oneDayInSeconds: TimeInterval = 86400
        
        /// Sleep debt weekly calculation (7 * 3600 = 7 hours)
        static let weeklyHours: TimeInterval = 7 * 3600
        
        /// Quality score maximum value for scaling (100%)
        static let maxQualityScore: Double = 100
        
        /// Progress bar calculation base (100 for percentage)
        static let percentageBase: Double = 100
    }
}