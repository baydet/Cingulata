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

    init?(code: HTTPStatusCode) {
        switch code.rawValue {
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

    private func compareCodes(a: HTTPStatusCode?,_ b: HTTPStatusCode?) -> Bool {
        guard let a = a else {
            return true
        }
        guard let b = b else {
            return false
        }
        return a == b
    }


    public func has(codeGroup: HTTPStatusCodeGroup) -> Bool {
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

public enum HTTPStatusCode: Int {
    case NoStatusCode = 0
    case OK = 200
    case Created = 201
    case NoContent = 204
    case BadRequest = 400
    case Unauthorized = 401
    case Forbidden = 403
    case NotFound = 404
    case InternalServerError = 500
}

public protocol ServerErrorProtocol: ErrorType {
    var message: String { get }
}

public enum RequestError: ErrorType {
    case BuildRequestError(message: String)
    case HTTPRequestError(HTTPStatusCodeGroup, ServerErrorProtocol)
    case MappingError(MapperError)
}

private struct UnknownError: ServerErrorProtocol {
    var message: String {
        return "Unknown error"
    }
}

public typealias NSURLRequestBuilder = (parameters: [String:AnyObject]?, HTTPMethod: String, URL: NSURL) throws -> NSURLRequest

public class RequestOperation: Operation {

    public let requestMethod: Alamofire.Method
    public let requestMapping: (String?, DataMapper)?
    public let responseMappings: [(HTTPStatusCodeGroup, String?, DataMapper)]?
    public var errorBlock: (([RequestError]) -> Void)?
    public var successBlock: (([Any]) -> Void)?

    private let requestBuilder: NSURLRequestBuilder
    private let parameters: [String: AnyObject]?
    private let URL: NSURL
    private let internalQueue = NSOperationQueue()
    private var operationStartDate: NSDate = NSDate()

    public required init(requestMethod: Alamofire.Method, parameters:[String: AnyObject]?, requestBuilder: NSURLRequestBuilder, requestMapping: (String?, DataMapper)?, responseMappings: [(HTTPStatusCodeGroup, String?, DataMapper)]?, URL: NSURL) {

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
        guard let statusCodeValue = HTTPStatusCode(rawValue: statusCode), codeGroup = HTTPStatusCodeGroup(code: statusCodeValue) else {
            print("unexpected status code value")
            return
        }

        if let responseMappings = self.responseMappings, json = responseJSON {
            responseMappings
                .filter { $0.0.has(codeGroup) }
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
            let error = self.responseMappings?.flatMap{_, _, mapper in mapper.mappingResult as? ServerErrorProtocol}.first

            errors.append(RequestError.HTTPRequestError(codeGroup, error ?? UnknownError()))
        }
    }

    override func execute() {
        internalQueue.suspended = false
        operationStartDate = NSDate()

        do {
            let URLRequest = try requestBuilder(parameters: requestParameters(), HTTPMethod: requestMethod.rawValue, URL: URL)
            let httpOperation = AlamofireOperation(request: URLRequest)
            httpOperation.completionBlock = { [weak self] in
                self?.errors += httpOperation.errors
            }

            let mappingOperation = NSBlockOperation(){ [weak self] in
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

        if let rMapping = requestMapping {
            let json = rMapping.1.mapToJSON()
            if let key = rMapping.0 {
                resultDictionary = [:]
                resultDictionary?[key] = json
            } else {
                guard let jsonDict = json as? [String : AnyObject] else {
                    assert(false, "unable to assign non dictionary to zero key")
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
        let format = ".3"
        print(String(format:"\(requestMethod):\(URL.absoluteString) completed in %.3f sec.", interval))
        let requestErrors = errors.flatMap { $0 as? RequestError }
        if !(requestErrors.isEmpty) {
            print(requestErrors)

            errorBlock?(requestErrors)
        } else {
            let results = responseMappings?.flatMap { $0.2.mappingResult } ?? []

            successBlock?(results)
        }

        super.finish()
    }
}