//
//  UserArticleProgress+CoreDataProperties.swift
//  Zeez
//
//  Created by Daniel on 1/19/25.
//
//

import Foundation
import CoreData


extension UserArticleProgress {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<UserArticleProgress> {
        return NSFetchRequest<UserArticleProgress>(entityName: "UserArticleProgress")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var lastReadDate: Date?
    @NSManaged public var isCompleted: Bool
    @NSManaged public var bookmarked: Bool
    @NSManaged public var article: LearnArticle?
    @NSManaged public var userPreferences: UserPreferences?

}

extension UserArticleProgress : Identifiable {

}
