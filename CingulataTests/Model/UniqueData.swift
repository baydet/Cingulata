//
//  UniqueData.swift
//  Cingulata
//
//  Created by Alexander Evsyuchenya on 12/16/15.
//  Copyright © 2015 Alexander Evsyuchenya. All rights reserved.
//

import Foundation
import CoreData
import Cingulata
import ObjectMapper


class UniqueData: NSManagedObject, CoreDataMappable {
    
    convenience required init?(_ map: ObjectMapper.Map) {
        self.init(entity: NSEntityDescription(), insertIntoManagedObjectContext: nil)
    }
    
    static func identificationAttributes() -> [UniqueAttribute] {
        return [UniqueAttribute(modelKey: "identifier", jsonKey: "id")]
    }
    
    func mapping(map: ObjectMapper.Map) {
        identifier <- map["id"]
    }
    
}
