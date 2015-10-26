//
//  CoreDataMapper.swift
//  Cingulata
//
//  Created by Alexandr Evsyuchenya on 10/4/15.
//  Copyright © 2015 baydet. All rights reserved.
//

import CoreData
import ObjectMapper

public struct UniqueAttribute {
    public let modelKey: String
    public let jsonKey: String
    
    public init(modelKey: String, jsonKey: String) {
        self.modelKey = modelKey
        self.jsonKey = jsonKey
    }
}

public protocol CoreDataMappable: Mappable {
    static func identificationAttributes() -> [UniqueAttribute]
    static func predicate(attribute: UniqueAttribute, map: ObjectMapper.Map) -> NSPredicate?
}

public func defaultPredicate(attribute: UniqueAttribute, map: ObjectMapper.Map) -> NSPredicate? {
    let value: AnyObject? = map[attribute.jsonKey].value()
    guard let str = value else {
        return nil
    }
    return NSPredicate(format: "\(attribute.modelKey) == \(str)")
}

public extension CoreDataMappable {
    static func predicate(attribute: UniqueAttribute, map: ObjectMapper.Map) -> NSPredicate? {
        return defaultPredicate(attribute, map: map)
    }
}

public class CoreDataMapper<T where T: NSManagedObject, T:CoreDataMappable> : DefaultMapper<T> {
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
            print("Error during mapping \(localError)")
            return false
        }


        return true
    }
}

public struct ManagedObjectTransform<ObjectType where ObjectType: NSManagedObject, ObjectType:CoreDataMappable>: TransformType {
    public typealias Object = ObjectType
    public typealias JSON = AnyObject
    private let mapper: Mapper<ObjectType> = Mapper<ObjectType>()
    private let context: NSManagedObjectContext?

    init(context: NSManagedObjectContext?) {
        self.context = context
    }

    public func transformFromJSON(value: AnyObject?) -> Object? {
        guard let ctx = context, let json = value as? [String : AnyObject] else {
            return nil
        }
        return mapObjectFromJSON(json, mapper: mapper, inContext: ctx)
    }

    public func transformToJSON(value: Object?) -> JSON? {
        guard let object = value else {
            return nil
        }
        return mapper.toJSON(object)
    }
}

private func mapObjectFromJSON<T where T: NSManagedObject, T: CoreDataMappable>(jsonDictionary: [String : AnyObject], mapper: Mapper<T>, inContext context: NSManagedObjectContext) -> T? {
    if T.identificationAttributes().count > 0 {
        let identifiers = T.identificationAttributes()
        let map = Map(mappingType: ObjectMapper.MappingType.FromJSON, JSONDictionary: jsonDictionary)
        assert(identifiers.count >= 1, "you should set at least 1 identifier for \(T.self)")
        let predicates: [NSPredicate] = identifiers.flatMap{T.predicate($0, map: map)}
        let cachedObjects = context.find(entityType: T.self, predicate: NSCompoundPredicate(type: .AndPredicateType, subpredicates: predicates))
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