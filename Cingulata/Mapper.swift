//
//  Mapper
//  Cingulata
//
//  Created by Alexander Evsyuchenya on 10/3/15.
//  Copyright © 2015 baydet. All rights reserved.
//
import ObjectMapper

public protocol ObjectJSONMapper {
    var mappingResult: Any? { get }
    func mapToJSON() -> AnyObject?
    func mapToObject(json: AnyObject?) throws
}

public enum ExpectedResultType {
    case Object
    case Array
}

public enum MapperError: ErrorType {
    case WrongJSONFormat
}

public enum SourceObjectType<S> {
    case Object(S)
    case Array([S])
}

public class DefaultMapper<T: Mappable>: ObjectJSONMapper {
    private let expectedResultType: ExpectedResultType
    public private(set) var mappingResult: Any?

    let mapper: Mapper<T> = Mapper<T>()
    private var sourceObject: SourceObjectType<T>?

    public required init(sourceObject: SourceObjectType<T>? = nil, expectedResultType: ExpectedResultType = .Object) {
        self.sourceObject = sourceObject
        self.expectedResultType = expectedResultType
    }

    public func mapToJSON() -> AnyObject? {
        assert(sourceObject != nil, "sourceObject cannot be nil with toJSON mapping")
        guard let object = sourceObject else {
            return nil
        }
        switch object {
        case .Object(let o):
            return mapper.toJSON(o)
        case .Array(let a):
            return mapper.toJSONArray(a)
        }
    }

    public func mapToObject(json: AnyObject?) throws {
        guard let json: AnyObject = json else {
            return
        }
        switch expectedResultType {
        case .Object:
            if let dict = json as? [String:AnyObject] {
                mappingResult = mapFromJSON(dict)
            } else {
                throw MapperError.WrongJSONFormat
            }
        case .Array:
            if let array = json as? [[String:AnyObject]] {
                var mapResults: [T] = []
                for dict in array {
                    if let o = mapFromJSON(dict) {
                        mapResults.append(o)
                    }
                }
                mappingResult = mapResults
            } else {
                throw MapperError.WrongJSONFormat
            }
        }
    }

    func mapFromJSON(jsonDictionary: [String : AnyObject]) -> T? {
        return mapper.map(jsonDictionary)
    }
}
