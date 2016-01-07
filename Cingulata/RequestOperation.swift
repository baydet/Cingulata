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
import Pichi

/**
 Struct for HTTP status codes
 */
public struct HTTPStatusCode : OptionSetType {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    
    public static let NoStatusCode =           HTTPStatusCode(rawValue: 0)

    public static let OK =                     HTTPStatusCode(rawValue: 200)
    public static let Created =                HTTPStatusCode(rawValue: 201)
    public static let NoContent =              HTTPStatusCode(rawValue: 204)

    public static let BadRequest =             HTTPStatusCode(rawValue: 400)
    public static let Unauthorized =           HTTPStatusCode(rawValue: 401)
    public static let PaymentRequired =        HTTPStatusCode(rawValue: 402)
    public static let Forbidden =              HTTPStatusCode(rawValue: 403)
    public static let NotFound =               HTTPStatusCode(rawValue: 404)
    public static let MethodNotAllowed =       HTTPStatusCode(rawValue: 405)
    public static let NotAcceptable =          HTTPStatusCode(rawValue: 406)
    public static let RequestTimeout =         HTTPStatusCode(rawValue: 408)
    public static let Conflict =               HTTPStatusCode(rawValue: 409)
    public static let Gone =                   HTTPStatusCode(rawValue: 410)
    
    public static let InternalServerError =    HTTPStatusCode(rawValue: 500)
    

    public static let NoCode: HTTPStatusCode =    [NoStatusCode]
    ///2xx status codes group
    public static let Success: HTTPStatusCode =   [OK, Created, NoContent]
    ///4xx status codes group
    public static let Client: HTTPStatusCode =    [BadRequest, Unauthorized, PaymentRequired, Forbidden, NotFound, MethodNotAllowed, NotAcceptable, RequestTimeout, Conflict, Gone]
    ///5xx status codes group
    public static let Server: HTTPStatusCode =    [InternalServerError]
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
    case HTTPRequestError(HTTPStatusCode, CinErrorProtocol)
    case MappingError(CinErrorProtocol)
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
        return ""
    }
}

public typealias Method = Alamofire.Method

/// function for creating NSURLRequest
public typealias NSURLRequestBuilder = (parameters: [String:AnyObject]?, HTTPMethod: String, URL: NSURL) throws -> NSURLRequest

/** 
*   Tuple for request mapping
*   - parameter key: destination key in parameters dictionary. Added in root if is 'nil'
*   - parameter mapper: mapper from Mappable to JSON dictionary
*/
public typealias RequestObjectMapping = (key: String?, mapper: TransformType, sourceObject: Any)

enum JSON {
    case Number
    case JString
    case Bool
    indirect case Array([JSON])
    indirect case Dictionary([String: JSON])
}

public typealias ResponseObjectMapping = (code: HTTPStatusCode, key: String?, mapping: TransformType)

/// Main operation class that manages following steps of REST operation: creating NSURLrequest, performing this request, parsing result to application's model
public class RequestOperation: Operation {
    /// called on the following operation failures: error during creating URL reuqest, executing, mapping results, or Client 4xx or Server 5xx errors
    public var errorBlock: (([RequestError]) -> Void)?
    /// executed if NSURLRequest executed with 2xx statusCode and mapping successfully completed
    public var successBlock: (([Any]) -> Void)?

    private let requestMethod: Alamofire.Method
    private let requestMapping: RequestObjectMapping?
    private let responseMappings: [ResponseObjectMapping]?
    private let requestBuilder: NSURLRequestBuilder
    private let parameters: [String: AnyObject]?
    private let URL: NSURL
    private let internalQueue = NSOperationQueue()
    private var operationStartDate: NSDate = NSDate()
    private var mappingResults: [Any] = []
    
    /**
     Default request initialization flow
     
     - parameter requestMethod:    HTTP request method: GET, POST, PUT, etc.
     - parameter parameters:       Optional dictionary of request parameters
     - parameter requestBuilder:   function for building NSURLRequest
     - parameter requestMapping:   tuple for creating JSON dictionary from application's model object. This value after merged with parameters dictionary
     - parameter responseMappings: array of response mappers
     - parameter URL:              url for the REST resource
     
     - returns: RequestOperation object
     */
    public required init(requestMethod: Method, parameters:[String: AnyObject]? = nil, requestBuilder: NSURLRequestBuilder, requestMapping: RequestObjectMapping? = nil, responseMappings: [ResponseObjectMapping]? = nil, URL: NSURL) {

        self.parameters = parameters
        self.requestMethod = requestMethod
        self.requestMapping = requestMapping
        self.responseMappings = responseMappings
        self.requestBuilder = requestBuilder
        self.URL = URL

        super.init()

        internalQueue.maxConcurrentOperationCount = 1
        internalQueue.suspended = true

        self.qualityOfService = .UserInitiated
    }

    private func map(statusCode: Int, responseJSON: AnyObject?) {
        let code = HTTPStatusCode(rawValue: statusCode)

        if let responseMappings = self.responseMappings, json = responseJSON {
            responseMappings
                .filter { $0.code.contains(code) }
                .forEach { _, key, mapper in
                    //
                    let mappedJSON: AnyObject?

                    if let key = key, dict = json as? [String : AnyObject] {
                        mappedJSON = dict[key]
                    } else {
                        mappedJSON = json
                    }

                    //
//                    do {
//                    mapper.transformFromJSON(json)
//                        if let json = mappedJSON, let object = try mapper.mapToObject(json) {
//                            mappingResults.append(object)
//                        }
//                    } catch let error as MapperError {
//                        errors.append(RequestError.MappingError(error))
//                    } catch {
//                        // Nothing to do
//                    }
                }
        }

        if HTTPStatusCode.Server.contains(code) || HTTPStatusCode.Client.contains(code) {
            let error = mappingResults.flatMap{$0 as? CinErrorProtocol }.first

            errors.append(RequestError.HTTPRequestError(code, error ?? UnknownError()))
        }
    }

    override func execute() {
        internalQueue.suspended = false
        operationStartDate = NSDate()

        do {
            let URLRequest = try requestBuilder(parameters: requestParameters(), HTTPMethod: requestMethod.rawValue, URL: URL)
            let httpOperation = AlamofireOperation(request: URLRequest)
            httpOperation.completionBlock = { [weak self, unowned httpOperation] in
                if let statusCode = httpOperation.statusCode {
                    let group = HTTPStatusCode(rawValue: statusCode)
                    guard HTTPStatusCode.Server.contains(group) || HTTPStatusCode.Client.contains(group) || HTTPStatusCode.NoCode.contains(group) else {
                        return
                    }
                }
                
                self?.errors += (httpOperation.errors
                    .flatMap { $0 as NSError }
                    .flatMap { RequestError.HTTPRequestError(HTTPStatusCode.NoCode, URLRequestError(error: $0)) }) as [ErrorType]
            }

            let mappingOperation = NSBlockOperation(){ [weak self] in
                guard self?.errors.count == 0 else {
                    return
                }
                guard let statusCode = httpOperation.statusCode else {
                    self?.errors.append(RequestError.HTTPRequestError(.NoCode, UnknownError()))

                    return
                }

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

        if let requestMapping = requestMapping {
            let json = [:];//requestMapping.mapper.mapToJSON(requestMapping.sourceObject)
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
        if let params = parameters {
            if resultDictionary == nil {
                resultDictionary = parameters
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
        print(String(format:"\(requestMethod):\(URL.absoluteString) completed in %.3f sec.", interval))
        let requestErrors = errors.flatMap { $0 as? RequestError }
        if !(requestErrors.isEmpty) {
            print(requestErrors)

            errorBlock?(requestErrors)
        } else {

            successBlock?(mappingResults)
        }

        super.finish()
    }
}
