//
//  GlossaryTerm+CoreDataProperties.swift
//  Zeez
//
//  Created by Daniel on 1/19/25.
//
//

import Foundation
import CoreData


extension GlossaryTerm {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<GlossaryTerm> {
        return NSFetchRequest<GlossaryTerm>(entityName: "GlossaryTerm")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var term: String?
    @NSManaged public var definition: String?
    @NSManaged public var category: String?
    @NSManaged public var sortOrder: Int16
    @NSManaged public var createdAt: Date?
    @NSManaged public var modifiedAt: Date?
    @NSManaged public var relatedTerms: NSSet?
    @NSManaged public var relatedArticles: NSSet?

}

// MARK: Generated accessors for relatedTerms
extension GlossaryTerm {

    @objc(addRelatedTermsObject:)
    @NSManaged public func addToRelatedTerms(_ value: GlossaryTerm)

    @objc(removeRelatedTermsObject:)
    @NSManaged public func removeFromRelatedTerms(_ value: GlossaryTerm)

    @objc(addRelatedTerms:)
    @NSManaged public func addToRelatedTerms(_ values: NSSet)

    @objc(removeRelatedTerms:)
    @NSManaged public func removeFromRelatedTerms(_ values: NSSet)

}

// MARK: Generated accessors for relatedArticles
extension GlossaryTerm {

    @objc(addRelatedArticlesObject:)
    @NSManaged public func addToRelatedArticles(_ value: LearnArticle)

    @objc(removeRelatedArticlesObject:)
    @NSManaged public func removeFromRelatedArticles(_ value: LearnArticle)

    @objc(addRelatedArticles:)
    @NSManaged public func addToRelatedArticles(_ values: NSSet)

    @objc(removeRelatedArticles:)
    @NSManaged public func removeFromRelatedArticles(_ values: NSSet)

}

extension GlossaryTerm : Identifiable {

}
