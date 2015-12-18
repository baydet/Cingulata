//
//  ManagedData+CoreDataProperties.swift
//  Cingulata
//
//  Created by Alexander Evsyuchenya on 12/16/15.
//  Copyright © 2015 Alexander Evsyuchenya. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension ManagedData {

    @NSManaged var text: String?
    @NSManaged var identifier: NSNumber?

}
