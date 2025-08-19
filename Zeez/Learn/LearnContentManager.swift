import CoreData
import Foundation
import os.log

/// Manages the creation, loading, and maintenance of learning content in the app
class LearnContentManager {
    static let shared = LearnContentManager()
    private let loadingQueue = DispatchQueue(label: "LearnContentManager.loading", qos: .utility)
    private var _loadedDefaultContent = false
    private let loadLock = NSLock()
    
    private var loadedDefaultContent: Bool {
        get {
            loadLock.lock()
            defer { loadLock.unlock() }
            return _loadedDefaultContent
        }
        set {
            loadLock.lock()
            defer { loadLock.unlock() }
            _loadedDefaultContent = newValue
        }
    }
    
    private init() {}
    
    /// Ensures default content exists in the database
    func ensureDefaultContent(context: NSManagedObjectContext) {
        guard !loadedDefaultContent else { return }
        
        context.perform { [weak self] in
            guard let self = self else { return }
            
            // Double-check pattern to prevent race conditions
            guard !self.loadedDefaultContent else { return }
            
            // Only load if we have no existing content
            let articleFetch: NSFetchRequest<LearnArticle> = LearnArticle.fetchRequest()
            let challengeFetch: NSFetchRequest<LearnChallenge> = LearnChallenge.fetchRequest()
            
            do {
                let articleCount = try context.count(for: articleFetch)
                let challengeCount = try context.count(for: challengeFetch)
                
                if articleCount == 0 && challengeCount == 0 {
                    self.createDefaultContent(in: context)
                    try context.save()
                    self.loadedDefaultContent = true
                } else {
                    // Content already exists, mark as loaded
                    self.loadedDefaultContent = true
                }
            } catch {
                ZeezLogger.error(ZeezLogger.learning, "Error ensuring default content", error: error)
            }
        }
    }
    
    private func createDefaultContent(in context: NSManagedObjectContext) {
        // Create Sleep Basics Articles
        let circadianRhythm = createArticle(
            title: "Understanding Your Circadian Rhythm",
            category: .basics,
            readTime: 5,
            sortOrder: 1,
            content: ArticleContent.circadianRhythm,
            context: context
        )
        
        let sleepStages = createArticle(
            title: "Sleep Stages Explained",
            category: .basics,
            readTime: 7,
            sortOrder: 2,
            content: ArticleContent.sleepStages,
            context: context
        )
        
        // Create Optimization Articles
        let optimalEnvironment = createArticle(
            title: "Creating the Perfect Sleep Environment",
            category: .optimization,
            readTime: 6,
            sortOrder: 1,
            content: ArticleContent.sleepEnvironment,
            context: context
        )
        
        _ = createArticle(
            title: "Sleep Hygiene Best Practices",
            category: .optimization,
            readTime: 8,
            sortOrder: 2,
            content: ArticleContent.sleepHygiene,
            context: context
        )
        
        // Create Science Articles
        let brainSleep = createArticle(
            title: "How Sleep Affects Your Brain",
            category: .science,
            readTime: 10,
            sortOrder: 1,
            content: ArticleContent.brainAndSleep,
            context: context
        )
        
        _ = createArticle(
            title: "The Evolution of Sleep",
            category: .science,
            readTime: 8,
            sortOrder: 2,
            content: ArticleContent.sleepEvolution,
            context: context
        )
        
        // Create Challenges
        createChallenge(
            title: "Consistent Sleep Schedule",
            description: "Maintain a consistent sleep and wake time for one week",
            type: .behavioral,
            duration: 7,
            points: 100,
            requirements: ["Go to bed within 30 minutes of your target bedtime",
                         "Wake up within 30 minutes of your target wake time",
                         "Maintain schedule for 7 consecutive days"],
            relatedArticles: [circadianRhythm],
            context: context
        )
        
        createChallenge(
            title: "Perfect Sleep Environment",
            description: "Optimize your bedroom for better sleep",
            type: .behavioral,
            duration: 3,
            points: 50,
            requirements: ["Ensure room temperature is between 60-67°F (15-19°C)",
                         "Remove all sources of blue light",
                         "Use blackout curtains or sleep mask",
                         "Maintain quiet or use white noise"],
            relatedArticles: [optimalEnvironment],
            context: context
        )
        
        createChallenge(
            title: "Sleep Science Master",
            description: "Learn the fundamentals of sleep science",
            type: .educational,
            duration: 5,
            points: 75,
            requirements: ["Read all Sleep Basics articles",
                         "Complete the sleep stages quiz",
                         "Track your sleep for 5 consecutive nights"],
            relatedArticles: [sleepStages, brainSleep],
            context: context
        )
    }
    
    private func createArticle(
        title: String,
        category: LearnCategory,
        readTime: Int16,
        sortOrder: Int16,
        content: String,
        context: NSManagedObjectContext
    ) -> LearnArticle {
        let article = LearnArticle(context: context)
        article.id = UUID()
        article.title = title
        article.content = content
        article.category = category.rawValue
        article.readTimeMinutes = readTime
        article.sortOrder = sortOrder
        article.createdAt = Date()
        article.modifiedAt = Date()
        return article
    }
    
    private func createChallenge(
        title: String,
        description: String,
        type: LearnChallengeType,
        duration: Int16,
        points: Int32,
        requirements: [String],
        relatedArticles: [LearnArticle],
        context: NSManagedObjectContext
    ) {
        let challenge = LearnChallenge(context: context)
        challenge.id = UUID()
        challenge.title = title
        challenge.challengeDescription = description
        challenge.type = type.rawValue
        challenge.durationDays = duration
        challenge.points = points
        challenge.isActive = false
        
        // Encode requirements as JSON data
        let encoder = JSONEncoder()
        if let requirementsData = try? encoder.encode(requirements) {
            challenge.requirements = requirementsData
        }
        
        // Add related articles
        let articlesSet = NSSet(array: relatedArticles)
        challenge.relatedArticles = articlesSet
    }
}

// MARK: - Article Content
private enum ArticleContent {
    static let circadianRhythm = """
    Your circadian rhythm is your body's internal clock that regulates your sleep-wake cycle. This 24-hour cycle is influenced by external factors like light and temperature, but it's primarily controlled by a part of your brain called the suprachiasmatic nucleus (SCN).

    Understanding and working with your circadian rhythm can dramatically improve your sleep quality. Here's what you need to know:

    1. Light Exposure
    - Morning light helps reset your circadian rhythm
    - Evening light, especially blue light, can disrupt it
    - Try to get natural light exposure during the day

    2. Temperature Changes
    - Your body temperature naturally drops during sleep
    - A cool bedroom (around 65°F/18°C) supports this process
    - Avoid exercise close to bedtime as it raises body temperature

    3. Timing Matters
    - Try to sleep and wake at consistent times
    - Your body releases melatonin at roughly the same time each night
    - Irregular schedules can lead to "social jet lag"

    Working with your circadian rhythm rather than against it can help you:
    - Fall asleep more easily
    - Wake up feeling refreshed
    - Maintain better energy throughout the day
    - Improve overall health and wellbeing
    """

    static let sleepStages = """
    Sleep isn't just one state - it's a complex process with multiple distinct stages. Understanding these stages can help you appreciate why quality sleep is so important.

    The Main Sleep Stages:

    1. Light Sleep (N1 & N2)
    - Initial transition from wakefulness
    - Muscle activity slows
    - May experience sudden muscle contractions
    - Makes up about 50% of total sleep

    2. Deep Sleep (N3)
    - Also called slow-wave sleep
    - Critical for physical recovery
    - Growth hormone release
    - Memory consolidation
    - Occurs more in the first half of the night

    3. REM Sleep
    - Rapid Eye Movement sleep
    - Dreams occur
    - Brain is highly active
    - Muscle paralysis occurs
    - Important for emotional processing
    - More frequent in the second half of the night

    A typical night includes 4-6 sleep cycles, each lasting about 90 minutes. Each cycle contains all stages, but the proportion of each stage varies throughout the night.
    """

    static let sleepEnvironment = """
    Your sleep environment plays a crucial role in the quality of your rest. Here's how to optimize your bedroom for better sleep:

    1. Temperature
    - Keep your room between 60-67°F (15-19°C)
    - Use breathable bedding materials
    - Consider a fan for air circulation

    2. Light
    - Install blackout curtains or shades
    - Remove or cover LED lights
    - Use warm, dim lighting before bed
    - Consider a sleep mask

    3. Sound
    - Address noise issues with earplugs or white noise
    - Seal gaps under doors
    - Consider upgrading windows
    - Use a white noise machine if needed

    4. Comfort
    - Invest in a quality mattress and pillows
    - Replace bedding regularly
    - Keep your bedroom clean and clutter-free
    - Consider air quality (use a purifier if needed)

    5. Electronics
    - Remove or cover devices with lights
    - Keep phones and tablets out of the bedroom
    - Use "do not disturb" mode
    - Position alarm clocks away from your bed
    """

    static let sleepHygiene = """
    Sleep hygiene refers to the habits and practices that help you get quality sleep. Here are evidence-based practices for better sleep:

    1. Daily Habits
    - Maintain a consistent sleep schedule
    - Get regular exercise (but not too close to bedtime)
    - Expose yourself to natural daylight
    - Limit daytime naps to 20-30 minutes

    2. Evening Routine
    - Avoid caffeine 6-8 hours before bed
    - Don't eat large meals close to bedtime
    - Limit alcohol and nicotine
    - Create a relaxing pre-bed routine

    3. Technology Use
    - Stop using screens 1-2 hours before bed
    - Use blue light filters on devices
    - Keep phones out of the bedroom
    - Avoid checking time during the night

    4. Mental Preparation
    - Practice relaxation techniques
    - Write down worries or tomorrow's tasks
    - Use mindfulness or meditation
    - Read a book or listen to calming music
    """

    static let brainAndSleep = """
    Sleep plays a vital role in brain health and function. During sleep, your brain undergoes several crucial processes:

    1. Memory Consolidation
    - Short-term memories convert to long-term
    - Skills and procedures are reinforced
    - Emotional memories are processed
    - Unnecessary information is pruned

    2. Brain Cleaning
    - The glymphatic system activates
    - Toxic proteins are cleared
    - Brain cells shrink to allow better cleaning
    - Cerebral spinal fluid flow increases

    3. Neural Maintenance
    - Synaptic connections are strengthened
    - New neural pathways form
    - Brain cells repair themselves
    - Energy stores are replenished

    4. Cognitive Impact of Sleep Loss
    - Reduced attention and focus
    - Impaired decision making
    - Slower reaction times
    - Mood regulation problems
    """

    static let sleepEvolution = """
    Sleep has evolved over millions of years to become an essential part of life. Here's how and why sleep developed:

    1. Early Evolution
    - Simple organisms showed rest-activity cycles
    - Basic nervous systems developed circadian rhythms
    - Sleep provided protection from predators
    - Energy conservation was crucial

    2. Mammals and Birds
    - Developed distinct sleep stages
    - REM sleep emerged
    - Brain size increased, requiring more sleep
    - Social behavior influenced sleep patterns

    3. Human Sleep Adaptations
    - Shorter sleep duration than other primates
    - More consolidated sleep periods
    - Enhanced memory processing
    - Complex dream capabilities

    4. Modern Challenges
    - Artificial light disrupts natural patterns
    - 24/7 society affects sleep timing
    - Technology impacts sleep quality
    - Sleep disorders become more common
    """
}
