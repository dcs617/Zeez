//
//  ScientificReference+CoreDataProperties.swift
//  Zeez
//
//  Created by Daniel on 1/19/25.
//
//

import Foundation
import CoreData


extension ScientificReference {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ScientificReference> {
        return NSFetchRequest<ScientificReference>(entityName: "ScientificReference")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var authors: String?
    @NSManaged public var journal: String?
    @NSManaged public var year: Int16
    @NSManaged public var doi: String?
    @NSManaged public var url: String?
    @NSManaged public var abstract: String?
    @NSManaged public var citation: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var modifiedAt: Date?
    @NSManaged public var articles: NSSet?

}

// MARK: Generated accessors for articles
extension ScientificReference {

    @objc(addArticlesObject:)
    @NSManaged public func addToArticles(_ value: LearnArticle)

    @objc(removeArticlesObject:)
    @NSManaged public func removeFromArticles(_ value: LearnArticle)

    @objc(addArticles:)
    @NSManaged public func addToArticles(_ values: NSSet)

    @objc(removeArticles:)
    @NSManaged public func removeFromArticles(_ values: NSSet)

}

extension ScientificReference : Identifiable {

}
