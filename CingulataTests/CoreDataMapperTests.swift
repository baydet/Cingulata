//
//  CoreDataMapperTests.swift
//  Cingulata
//
//  Created by Alexandr Evsyuchenya on 10/25/15.
//  Copyright © 2015 baydet. All rights reserved.
//

import XCTest
import CoreData
@testable import Cingulata


class CoreDataMapperTests: XCTestCase {
    var context: NSManagedObjectContext!
    
    override func setUp() {
        super.setUp()
        let bundle = NSBundle(forClass: self.classForCoder)
        
        let model = NSManagedObjectModel(contentsOfURL: bundle.URLForResource("Model", withExtension: "momd")!)!
        let storeCoordinator: NSPersistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        context = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        context.persistentStoreCoordinator = storeCoordinator
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testCoreDataMapping() {
        guard let object: ManagedData = context.insert() else {
            return
        }
        object.text = "test"
        object.identifier = 13
        let mapper = CoreDataMapper<ManagedData>(context: context)
        let json = mapper.mapToJSON(object)!
        let mappedObject = try! mapper.mapToObject(json) as! ManagedData
        XCTAssertEqual(mappedObject.identifier, object.identifier)
        XCTAssertEqual(mappedObject.text, object.text)
        XCTAssertEqual(context.find(entityType: ManagedData.self).count, 2)
    }
    
    func testUniqueCoreDataMapping() {
        let mapper = CoreDataMapper<UniqueData>(context: context)
        let object = try! mapper.mapToObject(["id" : 13]) as! UniqueData
        XCTAssertEqual(context.find(entityType: UniqueData.self).count, 1)
        
        let json = mapper.mapToJSON(object)!
        let mappedObject = try! mapper.mapToObject(json) as! UniqueData
        XCTAssertEqual(mappedObject.identifier, object.identifier)
        
        XCTAssertEqual(context.find(entityType: UniqueData.self).count, 1)
    }
    
    func testDeleteOrphanedObjects() {
        
    }

}
