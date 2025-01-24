//
//  UserPreferences+CoreDataProperties.swift
//  Zeez
//
//  Created by Daniel on 1/19/25.
//
//

import Foundation
import CoreData


extension UserPreferences {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserPreferences> {
        return NSFetchRequest<UserPreferences>(entityName: "UserPreferences")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var targetSleepDuration: Double
    @NSManaged public var targetBedtime: Date?
    @NSManaged public var targetWakeTime: Date?
    @NSManaged public var sleepGoalEnabled: Bool
    @NSManaged public var notificationsEnabled: Bool
    @NSManaged public var healthKitSyncEnabled: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var modifiedAt: Date?
    @NSManaged public var alarmConfigurations: NSSet?
    @NSManaged public var analyticsEvent: NSSet?
    @NSManaged public var subscriptionEvents: NSSet?
    @NSManaged public var featureAccess: NSSet?
    @NSManaged public var upgradeEvents: NSSet?
    @NSManaged public var articleProgress: NSSet?
    @NSManaged public var challengeBadges: NSSet?
    @NSManaged public var quizProgress: NSSet?
    @NSManaged public var viewedFacts: NSSet?

}

// MARK: Generated accessors for alarmConfigurations
extension UserPreferences {

    @objc(addAlarmConfigurationsObject:)
    @NSManaged public func addToAlarmConfigurations(_ value: AlarmConfiguration)

    @objc(removeAlarmConfigurationsObject:)
    @NSManaged public func removeFromAlarmConfigurations(_ value: AlarmConfiguration)

    @objc(addAlarmConfigurations:)
    @NSManaged public func addToAlarmConfigurations(_ values: NSSet)

    @objc(removeAlarmConfigurations:)
    @NSManaged public func removeFromAlarmConfigurations(_ values: NSSet)

}

// MARK: Generated accessors for analyticsEvent
extension UserPreferences {

    @objc(addAnalyticsEventObject:)
    @NSManaged public func addToAnalyticsEvent(_ value: AnalyticsEvent)

    @objc(removeAnalyticsEventObject:)
    @NSManaged public func removeFromAnalyticsEvent(_ value: AnalyticsEvent)

    @objc(addAnalyticsEvent:)
    @NSManaged public func addToAnalyticsEvent(_ values: NSSet)

    @objc(removeAnalyticsEvent:)
    @NSManaged public func removeFromAnalyticsEvent(_ values: NSSet)

}

// MARK: Generated accessors for subscriptionEvents
extension UserPreferences {

    @objc(addSubscriptionEventsObject:)
    @NSManaged public func addToSubscriptionEvents(_ value: SubscriptionEventRecord)

    @objc(removeSubscriptionEventsObject:)
    @NSManaged public func removeFromSubscriptionEvents(_ value: SubscriptionEventRecord)

    @objc(addSubscriptionEvents:)
    @NSManaged public func addToSubscriptionEvents(_ values: NSSet)

    @objc(removeSubscriptionEvents:)
    @NSManaged public func removeFromSubscriptionEvents(_ values: NSSet)

}

// MARK: Generated accessors for featureAccess
extension UserPreferences {

    @objc(addFeatureAccessObject:)
    @NSManaged public func addToFeatureAccess(_ value: FeatureAccessRecord)

    @objc(removeFeatureAccessObject:)
    @NSManaged public func removeFromFeatureAccess(_ value: FeatureAccessRecord)

    @objc(addFeatureAccess:)
    @NSManaged public func addToFeatureAccess(_ values: NSSet)

    @objc(removeFeatureAccess:)
    @NSManaged public func removeFromFeatureAccess(_ values: NSSet)

}

// MARK: Generated accessors for upgradeEvents
extension UserPreferences {

    @objc(addUpgradeEventsObject:)
    @NSManaged public func addToUpgradeEvents(_ value: UpgradeEventRecord)

    @objc(removeUpgradeEventsObject:)
    @NSManaged public func removeFromUpgradeEvents(_ value: UpgradeEventRecord)

    @objc(addUpgradeEvents:)
    @NSManaged public func addToUpgradeEvents(_ values: NSSet)

    @objc(removeUpgradeEvents:)
    @NSManaged public func removeFromUpgradeEvents(_ values: NSSet)

}

// MARK: Generated accessors for articleProgress
extension UserPreferences {

    @objc(addArticleProgressObject:)
    @NSManaged public func addToArticleProgress(_ value: UserArticleProgress)

    @objc(removeArticleProgressObject:)
    @NSManaged public func removeFromArticleProgress(_ value: UserArticleProgress)

    @objc(addArticleProgress:)
    @NSManaged public func addToArticleProgress(_ values: NSSet)

    @objc(removeArticleProgress:)
    @NSManaged public func removeFromArticleProgress(_ values: NSSet)

}

// MARK: Generated accessors for challengeBadges
extension UserPreferences {

    @objc(addChallengeBadgesObject:)
    @NSManaged public func addToChallengeBadges(_ value: ChallengeBadge)

    @objc(removeChallengeBadgesObject:)
    @NSManaged public func removeFromChallengeBadges(_ value: ChallengeBadge)

    @objc(addChallengeBadges:)
    @NSManaged public func addToChallengeBadges(_ values: NSSet)

    @objc(removeChallengeBadges:)
    @NSManaged public func removeFromChallengeBadges(_ values: NSSet)

}

// MARK: Generated accessors for quizProgress
extension UserPreferences {

    @objc(addQuizProgressObject:)
    @NSManaged public func addToQuizProgress(_ value: QuizProgress)

    @objc(removeQuizProgressObject:)
    @NSManaged public func removeFromQuizProgress(_ value: QuizProgress)

    @objc(addQuizProgress:)
    @NSManaged public func addToQuizProgress(_ values: NSSet)

    @objc(removeQuizProgress:)
    @NSManaged public func removeFromQuizProgress(_ values: NSSet)

}

// MARK: Generated accessors for viewedFacts
extension UserPreferences {

    @objc(addViewedFactsObject:)
    @NSManaged public func addToViewedFacts(_ value: SleepFact)

    @objc(removeViewedFactsObject:)
    @NSManaged public func removeFromViewedFacts(_ value: SleepFact)

    @objc(addViewedFacts:)
    @NSManaged public func addToViewedFacts(_ values: NSSet)

    @objc(removeViewedFacts:)
    @NSManaged public func removeFromViewedFacts(_ values: NSSet)

}

extension UserPreferences : Identifiable {

}
