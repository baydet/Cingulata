//
//  RequestOperation.swift
//  Cingulata
//
//  Created by Alexander Evsyuchenya on 10/3/15.
//  Copyright © 2015 baydet. All rights reserved.
//

import Foundation
import Alamofire
import CoreData

public enum HTTPStatusCodeGroup {
    case NoCode
    case Success(HTTPStatusCode?)
    case Client(HTTPStatusCode?)
    case Server(HTTPStatusCode?)
    
    init?(intCode: Int) {
        let code = HTTPStatusCode(rawValue: intCode)
        switch intCode {
        case 0:
            self = .NoCode
        case 200...299:
            self = .Success(code)
        case 400...499:
            self = .Client(code)
        case 500...599:
            self = .Server(code)
        default:
            return nil
        }
    }
    
    func compareCodes(a: HTTPStatusCode?,_ b: HTTPStatusCode?) -> Bool {
        guard let a = a else {
            return true
        }
        guard let b = b else {
            return false
        }
        return a == b
    }
    
    func has(codeGroup: HTTPStatusCodeGroup) -> Bool {
        switch (self, codeGroup) {
        case (.Success(let a), .Success(let b)):
            return compareCodes(a, b)
        case (.Client(let a), .Client(let b)):
            return compareCodes(a, b)
        case (.Server(let a), .Server(let b)):
            return compareCodes(a, b)
        default:
            return false
        }
    }
}

/**
 Enum for HTTP status codes
 */
public enum HTTPStatusCode: Int {
    case NoStatusCode = 0
    case OK = 200
    case Created = 201
    case NoContent = 204
    case BadRequest = 400
    case Unauthorized = 401
    case PaymentRequired = 402
    case Forbidden = 403
    case NotFound = 404
    case MethodNotAllowed = 405
    case NotAcceptable = 406
    case RequestTimeout = 408
    case Conflict = 409
    case Gone = 410
    
    case InternalServerError = 500
}

/**
 *  All RequestOperation errors conform this protocol. If you want to see your your mapped error in errorBlock your error object should conform this protocol
 */
public protocol CinErrorProtocol: ErrorType {
    var message: String { get }
}

/**
 Enum of possible RequestOperation errors
 
 - BuildRequestError: error during building request. May occur if NSURLRequestBuilder returns nil request, or parameters dictionary cannot be generated
 - HTTPRequestError:  error during executing operation or in case of 4xx, 5xx error. Contains of optional error code and error object
 - MappingError:      operation executed successfully but mapping cannot be performed
 */
public enum RequestError: ErrorType {
    case BuildRequestError(message: String)
    case HTTPRequestError(HTTPStatusCodeGroup, CinErrorProtocol)
    case MappingError(MapperError)
}

/**
 *  Default implementation of CinErrorProtocol
 */
public struct URLRequestError: CinErrorProtocol {
    public let message: String
    public let error: NSError
    
    init(error: NSError) {
        message = error.localizedDescription
        self.error = error
    }
}

private struct UnknownError: CinErrorProtocol {
    var message: String {
        return "Unknown error"
    }
}

public typealias Method = Alamofire.Method

/**
 *   Tuple for request mapping
 *   - parameter key: destination key in parameters dictionary. Added in root if is 'nil'
 *   - parameter mapper: mapper from Mappable to JSON dictionary
 */
public typealias RequestObjectMapping = (key: String?, mapper: ObjectJSONMapper)

public typealias ResponseObjectMapping = (codeGroup: HTTPStatusCodeGroup, key: String?, mapping: ObjectJSONMapper)

/// Main operation class that manages following steps of REST operation: creating NSURLrequest, performing this request, parsing result to application's model
public class RequestOperation: Operation {
    /// called on the following operation failures: error during creating URL reuqest, executing, mapping results, or Client 4xx or Server 5xx errors
    public var errorBlock: (([RequestError]) -> Void)?
    /// executed if NSURLRequest executed with 2xx statusCode and mapping successfully completed
    public var successBlock: (([Any]) -> Void)?
    
    public let requestBuilder: RequestBuilder
    private let responseMappings: [ResponseObjectMapping]?
    
    private let internalQueue = NSOperationQueue()
    private var operationStartDate: NSDate = NSDate()
    
    public required init(requestBuilder: RequestBuilder) {
        self.requestBuilder = requestBuilder
        self.responseMappings = requestBuilder.responseMapping
        super.init()
        
        internalQueue.maxConcurrentOperationCount = 1
        internalQueue.suspended = true
        
        self.qualityOfService = .UserInitiated
    }
    
    private func map(statusCode: Int, responseJSON: AnyObject?) {
        guard let codeGroup = HTTPStatusCodeGroup(intCode: statusCode) else {
            print("unexpected status code value")
            return
        }
        
        if let responseMappings = responseMappings, json = responseJSON {
            responseMappings
                .filter { $0.codeGroup.has(codeGroup) }
                .forEach { _, key, mapper in
                    //
                    let mappedJSON: AnyObject?
                    
                    if let key = key, dict = json as? [String : AnyObject] {
                        mappedJSON = dict[key]
                    } else {
                        mappedJSON = json
                    }
                    
                    //
                    do {
                        try mapper.mapToObject(mappedJSON)
                    } catch let error as MapperError {
                        errors.append(RequestError.MappingError(error))
                    } catch {
                        // Nothing to do
                    }
            }
        }
        
        if HTTPStatusCodeGroup.Server(nil).has(codeGroup) || HTTPStatusCodeGroup.Client(nil).has(codeGroup) {
            let error = responseMappings?.flatMap{_, _, mapper in mapper.mappingResult as? CinErrorProtocol }.first
            
            errors.append(RequestError.HTTPRequestError(codeGroup, error ?? UnknownError()))
        }
    }
    
    override func execute() {
        internalQueue.suspended = false
        operationStartDate = NSDate()
        
        do {
            let URLRequest = try requestBuilder.requestBuilder(parameters: requestParameters(), HTTPMethod: requestBuilder.httpMethod.rawValue, URL: requestBuilder.URL)
            let httpOperation = AlamofireOperation(request: URLRequest)
            httpOperation.completionBlock = { [weak self, unowned httpOperation] in
                if let statusCode = httpOperation.statusCode, group = HTTPStatusCodeGroup(intCode: statusCode) {
                    guard HTTPStatusCodeGroup.Server(nil).has(group) || HTTPStatusCodeGroup.Client(nil).has(group) || HTTPStatusCodeGroup.NoCode.has(group) else {
                        return
                    }
                }
                
                self?.errors += (httpOperation.errors
                    .flatMap { $0 as NSError }
                    .flatMap { RequestError.HTTPRequestError(HTTPStatusCodeGroup.NoCode, URLRequestError(error: $0)) }) as [ErrorType]
            }
            
            let mappingOperation = NSBlockOperation(){ [weak self] in
                guard let strongSelf = self where strongSelf.errors.count == 0 else {
                    return
                }
                guard let statusCode = httpOperation.statusCode else {
                    strongSelf.errors.append(RequestError.HTTPRequestError(.NoCode, UnknownError()))
                    
                    return
                }
                self?.requestBuilder.cleanOrphanedObjects?()
                self?.map(statusCode, responseJSON: httpOperation.responseJSON)
            }
            
            let finishingOperation = NSBlockOperation(block: { [weak self] in
                self?.finish()
                })
            
            addOperation(httpOperation)
            addOperation(mappingOperation)
            addOperation(finishingOperation)
            
        } catch let nsError as NSError {
            errors.append(nsError)
            
            finish()
        }
    }
    
    private func addOperation(operation: NSOperation) {
        if let lastOperation = internalQueue.operations.last {
            operation.addDependency(lastOperation)
        }
        
        internalQueue.addOperation(operation)
    }
    
    private func requestParameters() -> [String : AnyObject]? {
        var resultDictionary: [String : AnyObject]? = nil
        
        if let requestMapping = requestBuilder.requestMapping {
            let json = requestMapping.mapper.mapToJSON()
            if let key = requestMapping.key {
                resultDictionary = [:]
                resultDictionary?[key] = json
            } else {
                guard let jsonDict = json as? [String : AnyObject] else {
                    return nil
                }
                resultDictionary = jsonDict
            }
            
        }
        if let params = requestBuilder.parameters {
            if resultDictionary == nil {
                resultDictionary = requestBuilder.parameters
            } else {
                for (key, value) in params {
                    resultDictionary?[key] = value
                }
            }
        }
        return resultDictionary
    }
    
    override func finish() {
        let interval = NSDate().timeIntervalSinceDate(operationStartDate)
        print(String(format:"\(requestBuilder.httpMethod):\(requestBuilder.URL.absoluteString) completed in %.3f sec.", interval))
        let requestErrors = errors.flatMap { $0 as? RequestError }
        if !(requestErrors.isEmpty) {
            print(requestErrors)
            
            errorBlock?(requestErrors)
        } else {
            let results = responseMappings?.flatMap { $0.mapping.mappingResult } ?? []
            
            successBlock?(results)
        }
        
        super.finish()
    }
}