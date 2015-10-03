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

public enum ResultType {
    case Success(AnyObject?)
    case Error(NSError)
}

public enum StatusCode: Int {
    case NoStatusCode = 0
    case OK = 200
    case Created = 201
    case BadRequest = 400
    case Unauthorized = 401
    case Forbidden = 403
    case NotFound = 404
    case InternalServerError = 500

    case ClientErrors
    case Success
    case ServerErrors

    private func containsCode(code: Int) -> Bool {
        switch self {
        case .ClientErrors:
            return code / 100 == 4
        case .Success:
            return code / 100 == 2
        case .ServerErrors:
            return code / 100 == 5
        default:
            return self.rawValue == code
        }
    }
}

protocol ServerErrorProtocol {
    var message: String? {get}
}

enum RequestError: ErrorType {
    case BuildError
    case HTTPRequestError(StatusCode, ServerErrorProtocol?)
    case MappingError(MapperError)
}

public typealias NSURLRequestBuilder = (parameters: [String:AnyObject]?, HTTPMethod: String, URL: NSURL) throws -> NSURLRequest

public class RequestOperation: Operation {

    public let requestMethod: Alamofire.Method
    public let requestMapping: (String, DataMapper)?
    public let responseMappings: [(StatusCode, String, DataMapper)]?
    public var errorBlock: (([ErrorType]) -> Void)?
    public var successBlock: (([Any]) -> Void)?

    private let requestBuilder: NSURLRequestBuilder
    private let parameters: [String: AnyObject]?
    private let URL: NSURL
    private let internalQueue = NSOperationQueue()

    public required init(requestMethod: Alamofire.Method, parameters:[String: AnyObject]?, requestBuilder: NSURLRequestBuilder, requestMapping: (String, DataMapper)?, responseMappings: [(StatusCode, String, DataMapper)]?, URL: NSURL) {
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
        guard let statusCodeValue = StatusCode(rawValue: statusCode) else {
            print("unexpected status code value")
            return
        }

        if let d = self.responseMappings, let json: AnyObject = responseJSON {
            let filteredMappings = d.filter{$0.0.containsCode(statusCode)}
            for (_, key, mapper) in filteredMappings {
                var mappedJSON: AnyObject?
                if (key.characters.count == 0) {
                    mappedJSON = json
                } else if let dict = json as? [String : AnyObject] {
                    mappedJSON = dict[key]
                } else {
                    //todo handle error unknown response Type
                }
                do {
                    try mapper.mapToObject(mappedJSON)
                } catch let error {
                    if let mapError = error as? MapperError {
                        self.errors.append(RequestError.MappingError(mapError))
                    }
                }
            }
        }

        if StatusCode.ServerErrors.containsCode(statusCodeValue.rawValue) || StatusCode.ClientErrors.containsCode(statusCodeValue.rawValue) {
            let error: ServerErrorProtocol? = self.responseMappings?.filter{$0.2.mappingResult is ServerErrorProtocol}.map{$0.2.mappingResult as! ServerErrorProtocol}.first
            self.errors.append(RequestError.HTTPRequestError(statusCodeValue, error))
        }
    }

    override func execute() {
        internalQueue.suspended = false

        do {
            let URLRequest = try requestBuilder(parameters: requestParameters(), HTTPMethod: requestMethod.rawValue, URL: URL)
            let httpOperation = AlamofireOperation(request: URLRequest)
            httpOperation.completionBlock = { [unowned self] in
                self.errors += httpOperation.errors
            }

            let mappingOperation = NSBlockOperation(){ [unowned self] in
                guard let statusCode = httpOperation.statusCode else {
                    self.errors.append(RequestError.HTTPRequestError(.NoStatusCode, nil))
                    return
                }
                self.map(statusCode, responseJSON: httpOperation.responseJSON)
            }

            let finishingOperation = NSBlockOperation(block: { [unowned self] in
                self.finish()
            })

            addOperation(httpOperation)
            addOperation(mappingOperation)
            addOperation(finishingOperation)

        } catch let error as NSError {
            errors.append(error)
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
        if let rMapping = requestMapping {
            let json = rMapping.1.mapToJSON()
            if rMapping.0.characters.count == 0 {
                guard let jsonDict = json as? [String : AnyObject] else {
                    assert(false, "unable to assign non dictionary to zero key")
                }
                resultDictionary = jsonDict
            } else {
                resultDictionary = [:]
                resultDictionary?[rMapping.0] = json
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
        if errors.count > 0 {
            if let block = errorBlock {
                block(errors)
            } else {
                print(errors)
            }
        } else {
            var mappingResults: [Any] = []
            if let mappings = responseMappings {
                for (_, _, mapper) in mappings {
                    guard let result = mapper.mappingResult else {
                        continue;
                    }
                    mappingResults.append(result)
                }
            }
            successBlock?(mappingResults)
        }
        super.finish()
    }
}