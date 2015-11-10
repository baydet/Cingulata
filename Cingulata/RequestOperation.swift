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

    private func compareCodes(a: HTTPStatusCode?,_ b: HTTPStatusCode?) -> Bool {
        guard let a = a else {
            return true
        }
        guard let b = b else {
            return false
        }
        return a == b
    }

    private func has(codeGroup: HTTPStatusCodeGroup) -> Bool {
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
public typealias RequestObjectMapping = (key: String?, mapper: ObjectJSONMapper)
public typealias ResponseObjectMapping = (codeGroup: HTTPStatusCodeGroup, key: String?, mapping: ObjectJSONMapper)

public class RequestOperation: Operation {
    public var errorBlock: (([RequestError]) -> Void)?
    public var successBlock: (([Any]) -> Void)?

    private let requestMethod: Alamofire.Method
    private let requestMapping: RequestObjectMapping?
    private let responseMappings: [ResponseObjectMapping]?
    private let requestBuilder: NSURLRequestBuilder
    private let parameters: [String: AnyObject]?
    private let URL: NSURL
    private let internalQueue = NSOperationQueue()

    private var operationStartDate: NSDate = NSDate()

    public required init(requestMethod: Alamofire.Method, parameters:[String: AnyObject]? = nil, requestBuilder: NSURLRequestBuilder, requestMapping: RequestObjectMapping? = nil, responseMappings: [ResponseObjectMapping]? = nil, URL: NSURL) {

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
        guard let codeGroup = HTTPStatusCodeGroup(intCode: statusCode) else {
            print("unexpected status code value")
            return
        }

        if let responseMappings = self.responseMappings, json = responseJSON {
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
            let error = self.responseMappings?.flatMap{_, _, mapper in mapper.mappingResult as? ServerErrorProtocol}.first

            errors.append(RequestError.HTTPRequestError(codeGroup, error ?? UnknownError()))
        }
    }

    override public func execute() {
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

        if let requestMapping = requestMapping {
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

    override public func finish() {
        let interval = NSDate().timeIntervalSinceDate(operationStartDate)
        print(String(format:"\(requestMethod):\(URL.absoluteString) completed in %.3f sec.", interval))
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