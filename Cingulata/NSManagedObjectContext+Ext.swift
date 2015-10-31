//
// Created by Alexandr Evsyuchenya on 10/25/15.
// Copyright (c) 2015 baydet. All rights reserved.
//

import Foundation
import CoreData

internal extension NSManagedObjectContext {
    func find<T : NSManagedObject>(entityType entityType: T.Type, predicate: NSPredicate? = nil) -> [T] {
        if let fetchRequest = fetchRequest(entityType: entityType) {
            fetchRequest.predicate = predicate

            return performFetchRequest(request: fetchRequest)
        } else {
            return []
        }
    }

    func fetchRequest<T : NSManagedObject>(entityType entityType: T.Type) -> NSFetchRequest? {
        if let description = self.entityDescription(entityType: entityType) {
            let request = NSFetchRequest()
            request.entity = description
            return request
        } else {
            print("ERROR: can't get entityDescriptionForClass: \(self) \nEntityName: \(entityType)")
            return nil
        }
    }

    func entityDescription<T : NSManagedObject>(entityType entityType: T.Type) -> NSEntityDescription? {
        if let entityName = NSStringFromClass(entityType).componentsSeparatedByString(".").last {
            return NSEntityDescription.entityForName(entityName, inManagedObjectContext: self)
        }
        else {
            return nil
        }
    }

    func performFetchRequest<T : NSManagedObject>(request request: NSFetchRequest) -> [T] {

        let requestThread = NSThread.currentThread()
        var resultArray: [AnyObject]?
        var error: NSError?

        performBlockAndWait {
            assert(NSThread.currentThread() == requestThread, "Fetch request in context called in wrong thread!")
            do {
                resultArray = try self.executeFetchRequest(request)
            } catch let error1 as NSError {
                error = error1
                resultArray = nil
            } catch {
                fatalError()
            }
        }

        if let results = resultArray as? [T] {
            return results
        } else {
            print("Error during DB fetch: \(error?.description)")
            return []
        }
    }

    func insert<T : NSManagedObject>() -> T? {
        if let description = entityDescription(entityType: T.self) {
            let obj = NSManagedObject(entity: description, insertIntoManagedObjectContext: self) as! T
            return obj
        } else {
            return nil
        }
    }
}