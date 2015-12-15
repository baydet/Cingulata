//
//  Mapper
//  Cingulata
//
//  Created by Alexander Evsyuchenya on 10/3/15.
//  Copyright © 2015 baydet. All rights reserved.
//
import ObjectMapper

public protocol ObjectJSONMapper {
    func mapToJSON(object: Any) -> AnyObject?
    func mapToObject(json: AnyObject) throws -> Any?
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
    let expectedResultType: ExpectedResultType

    let mapper: Mapper<T> = Mapper<T>()

    public required init(expectedResultType: ExpectedResultType = .Object) {
        self.expectedResultType = expectedResultType
    }

    public func mapToJSON(object: Any) -> AnyObject? {
        if let mappableObject = object as? T {
            return mapper.toJSON(mappableObject)
        }
        if let mappableArray = object as? [T] {
            return mapper.toJSONArray(mappableArray)
        }
        return nil
    }
    
    public func mapToObject(json: AnyObject) throws -> Any? {
        var mappingResult: Any? = nil
        guard let json: AnyObject = json else {
            return nil
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
        return mappingResult
    }

    func mapFromJSON(jsonDictionary: [String : AnyObject]) -> T? {
        return mapper.map(jsonDictionary)
    }
}
