//
//  LearnChallenge+CoreDataProperties.swift
//  Zeez
//
//  Created by Daniel on 1/19/25.
//
//

import Foundation
import CoreData


extension LearnChallenge {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<LearnChallenge> {
        return NSFetchRequest<LearnChallenge>(entityName: "LearnChallenge")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var challengeDescription: String?
    @NSManaged public var type: String?
    @NSManaged public var durationDays: Int16
    @NSManaged public var points: Int32
    @NSManaged public var isActive: Bool
    @NSManaged public var startDate: Date?
    @NSManaged public var endDate: Date?
    @NSManaged public var requirements: Data?
    @NSManaged public var userProgress: ChallengeBadge?
    @NSManaged public var relatedArticles: NSSet?

}

// MARK: Generated accessors for relatedArticles
extension LearnChallenge {

    @objc(addRelatedArticlesObject:)
    @NSManaged public func addToRelatedArticles(_ value: LearnArticle)

    @objc(removeRelatedArticlesObject:)
    @NSManaged public func removeFromRelatedArticles(_ value: LearnArticle)

    @objc(addRelatedArticles:)
    @NSManaged public func addToRelatedArticles(_ values: NSSet)

    @objc(removeRelatedArticles:)
    @NSManaged public func removeFromRelatedArticles(_ values: NSSet)

}

extension LearnChallenge : Identifiable {

}
