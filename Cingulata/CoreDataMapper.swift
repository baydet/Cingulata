//
//  CoreDataMapper.swift
//  Cingulata
//
//  Created by Alexandr Evsyuchenya on 10/4/15.
//  Copyright © 2015 baydet. All rights reserved.
//

import CoreData
import ObjectMapper

public protocol UniqueMappable : Mappable {
    static func identificationAttributes() -> [(String, String)]
}

public class CoreDataMapper<T where T: NSManagedObject, T: UniqueMappable> : DefaultMapper<T> {
    private let context: NSManagedObjectContext
    
    public required init(sourceObject: SourceObjectType<T>?, expectedResultType: ExpectedResultType = .Object, context: NSManagedObjectContext) {
        self.context = context
        super.init(sourceObject: sourceObject, expectedResultType: expectedResultType)
    }
    
    override public func mapToObject(json: AnyObject?) throws {
        try super.mapToObject(json)
        saveContext()
    }
    
    override func mapFromJSON(jsonDictionary: [String : AnyObject]) -> T? {
        return mapObjectFromJSON(jsonDictionary, mapper: mapper, inContext: context)
    }
    
    private func saveContext() -> Bool {
        var localError: NSError? = nil
        self.context.performBlockAndWait() {
            do {
                try self.context.obtainPermanentIDsForObjects(Array(self.context.insertedObjects))
            } catch let err as NSError {
                localError = err
            }
        }
        
        if localError != nil {
            return false
        }
        
        self.context.performBlockAndWait() {
            do {
                try self.context.save()
            } catch let err as NSError {
                localError = err
            }
        }
        
        if localError != nil {
            print("Saving of managed object context failed, but a `nil` value for the `error` argument was returned. This typically indicates an invalid implementation of a key-value validation method exists within your model. This violation of the API contract may result in the save operation being mis-interpretted by callers that rely on the availability of the error.")
            return false
        }
        
        
        return true
    }
}

struct ManagedObjectTransform<ObjectType where ObjectType: NSManagedObject, ObjectType: UniqueMappable>: TransformType {
    typealias Object = ObjectType
    typealias JSON = AnyObject
    private let mapper: Mapper<ObjectType> = Mapper<ObjectType>()
    private let context: NSManagedObjectContext?
    
    init(context: NSManagedObjectContext?) {
        self.context = context
    }
    
    func transformFromJSON(value: AnyObject?) -> Object? {
        guard let ctx = context, let json = value as? [String : AnyObject] else {
            return nil
        }
        return mapObjectFromJSON(json, mapper: mapper, inContext: ctx)
    }
    
    func transformToJSON(value: Object?) -> JSON? {
        return nil
    }
}

private func mapObjectFromJSON<T where T: NSManagedObject, T: UniqueMappable>(jsonDictionary: [String : AnyObject], mapper: Mapper<T>, inContext context: NSManagedObjectContext) -> T? {
    if T.identificationAttributes().count > 0 {
        var predicateString = ""
        let identifiers = T.identificationAttributes()
        let map = Map(mappingType: ObjectMapper.MappingType.FromJSON, JSONDictionary: jsonDictionary)
        assert(identifiers.count >= 1, "you should set at least 1 identifier for \(T.self)")
        for attribute in identifiers {
            let value: AnyObject? = map[attribute.1].value()
            guard let str = value else {
                continue
            }
            predicateString += "\(attribute.0) == \(str)"
            if attribute.0 != identifiers.last?.0 {
                predicateString += " AND "
            }
        }
        let predicate = NSPredicate(format: predicateString)
        let cachedObjects = context.find(entityType: T.self, predicate: predicate)
        if cachedObjects.count > 1 {
            print("Warning! More that one entity (\(cachedObjects.count)) of \(T.self) with identifiers \(identifiers) found")
        }
        
        guard let cachedObject = cachedObjects.first else {
            guard let newObject = context.insert(entityType: T.self) else {
                return nil
            }
            mapper.map(jsonDictionary, toObject: newObject)
            return newObject
        }
        mapper.map(jsonDictionary, toObject: cachedObject)
        return cachedObject
    }
    guard let object = context.insert(entityType: T.self) else {
        return nil
    }
    mapper.map(jsonDictionary, toObject: object)
    return object
}

private extension NSManagedObjectContext {
    func find<T : NSManagedObject>(entityType entityType: T.Type, predicate: NSPredicate? = nil) -> [T] {
        if let fetchRequest = fetchRequest(entityType: entityType) {
            fetchRequest.predicate = predicate
            
            return performFetchRequest(request: fetchRequest, entityType: entityType)
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
    
    func performFetchRequest<T : NSManagedObject>(request request: NSFetchRequest, entityType: T.Type) -> [T] {
        
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
    
    func insert<T : NSManagedObject>(entityType entityType: T.Type) -> T? {
        if let description = entityDescription(entityType: entityType) {
            let obj = NSManagedObject(entity: description, insertIntoManagedObjectContext: self) as! T
            return obj
        } else {
            return nil
        }
    }
}