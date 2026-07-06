/// Zeez Core Data Model Documentation
///
/// This document details the Core Data model structure, relationships,
/// and usage patterns for the Zeez sleep tracking app.
///
/// # Entity Descriptions
///
/// ## SleepSession
/// Central entity tracking individual sleep sessions.
/// - id: Unique identifier
/// - startTime: Session start
/// - endTime: Session completion
/// - isActive: Current tracking status
/// - qualityScore: Overall session quality
/// - Relationships:
///   - heartRateData: Heart rate measurements
///   - movementData: Motion and activity
///   - environmentalReadings: Room conditions
///   - sleepStages: Sleep stage classification
///   - notes: User annotations
///   - dailyMetrics: Aggregated daily stats
///
/// ## HeartRateData
/// Stores heart rate measurements during sleep.
/// - value: BPM reading
/// - timestamp: Measurement time
/// - confidence: Reading accuracy
/// - deviceType: Source device
/// - Relationships:
///   - session: Parent sleep session
///
/// ## MovementData
/// Tracks motion and restlessness.
/// - activityLevel: 0-5 scale
/// - magnitude: Movement intensity
/// - xAcceleration: X-axis motion
/// - yAcceleration: Y-axis motion
/// - zAcceleration: Z-axis motion
/// - Relationships:
///   - session: Parent sleep session
///
/// ## EnvironmentalReading
/// Records sleep environment conditions.
/// - lightLevel: Ambient light (lux)
/// - noiseLevel: Sound level (dB)
/// - temperature: Room temperature (°C)
/// - humidity: Room humidity (%)
/// - Relationships:
///   - session: Parent sleep session
///
/// ## DailyMetrics
/// Aggregates daily sleep statistics.
/// - date: Reference date
/// - totalSleepTime: Total sleep duration
/// - averageHeartRate: Mean heart rate
/// - sleepDebt: Sleep goal difference
/// - Relationships:
///   - sessions: Day's sleep sessions
///   - weeklyMetrics: Parent weekly stats
///
/// ## WeeklyMetrics
/// Weekly sleep pattern analysis.
/// - weekStartDate: Period start
/// - weekEndDate: Period end
/// - averageSleepTime: Mean sleep duration
/// - consistencyScore: Schedule regularity
/// - Relationships:
///   - dailyMetrics: Constituent daily stats
///
/// ## AlarmConfiguration
/// Manages sleep and wake scheduling.
/// - time: Alarm time
/// - enabled: Active status
/// - daysOfWeek: Repeat schedule
/// - smartWakeEnabled: Smart wake feature
/// - smartWakeWindow: Wake window duration
/// - Relationships:
///   - preferences: User preferences link
///
/// ## UserPreferences
/// Stores app configuration and settings.
/// - targetSleepDuration: Sleep goal
/// - healthKitSyncEnabled: Health sync status
/// - notificationsEnabled: Alert settings
/// - Relationships:
///   - alarmConfigurations: User's alarms
///
/// # Data Flow Patterns
///
/// ## Session Creation
/// ```swift
/// let session = SleepSession(context: context)
/// session.id = UUID()
/// session.startTime = Date()
/// session.isActive = true
/// ```
///
/// ## Data Collection
/// ```swift
/// let reading = EnvironmentalReading(context: context)
/// reading.session = currentSession
/// reading.timestamp = Date()
/// reading.lightLevel = capturedLight
/// ```
///
/// ## Metrics Calculation
/// ```swift
/// let metrics = DailyMetrics(context: context)
/// metrics.date = startOfDay
/// metrics.addToSessions(session)
/// metrics.calculateAggregates()
/// ```
///
/// # Query Optimization
///
/// - Use appropriate fetch predicates
/// - Include necessary relationships
/// - Configure proper indexes
/// - Batch updates when possible
///
/// # Sync Considerations
///
/// - Handle merge conflicts
/// - Maintain data integrity
/// - Consider offline operations
/// - Manage sync frequency
///
/// # Migration Strategy
///
/// Future model versions should:
/// - Preserve existing data
/// - Add new entities gradually
/// - Include fallback values
/// - Document changes thoroughly