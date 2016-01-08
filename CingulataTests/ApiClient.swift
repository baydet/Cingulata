//
//  ApiClient.swift
//  Cingulata
//
//  Created by Alexandr Evsyuchenya on 11/16/15.
//  Copyright © 2015 Alexander Evsyuchenya. All rights reserved.
//

import Foundation
import Cingulata
import Alamofire
import Pichi

func testDataMapping<M: Map>(inout data: TestData, map: M) {
    data.stringKey <-> map["key"]
    data.string2Key <-> map["key2"]
}

struct TestData: Mappable {
    var stringKey: String = ""
    var string2Key: String? = nil
    
    init() {
    }
    
    init<T:Map>(_ map: T) {
    }
    
}

struct NestedData: Mappable {
    var stringKey: String = ""
    
    init() {
    }
    
    init<T:Map>(_ map: T) {
        
    }

}

enum Endpoint: RequestBuilder {
    
    case NotFound
    case Data(object: TestData)
    case GetNestedData
    
    var URL: NSURL {
        let path: String!
        switch self {
        case .NotFound:
            path = "status/404"
        case .Data:
            path = "https://httpbin.org/response-headers"
        case .GetNestedData:
            path = "https://httpbin.org/get"
        }
        return NSURL(string: path, relativeToURL: NSURL(string: "https://httpbin.org"))!
    }
    var httpMethod: Cingulata.Method {
        switch self {
        default:
            return .GET
        }
    }
    
    var parameters: [String : AnyObject]? {
        switch self {
        case .Data(_):
            return ["key2" : "value2"]
        default:
            return nil
        }
    }
    var requestMapping: RequestObjectMapping? {
        switch self {
        case .Data(let data):
            return RequestObjectMapping(key: nil, sourceObject: data,  transform: RequestDictionaryMapping<TestData>(mapFunction: testDataMapping))
        default:
            return nil
        }
    }
    var requestBuilder: NSURLRequestBuilder {
        return defaultRequestBuilder
    }
    var responseMapping: [ResponseObjectMapping]? {
        switch self {
        case .Data:
            return [ResponseObjectMapping(code: HTTPStatusCode.Success, key: nil, transform: ResponseDictionaryMapping<TestData>(mapFunction: testDataMapping))]
        default:
            return nil
        }
    }
    
}

func defaultRequestBuilder(parameters: [String:AnyObject]?, HTTPMethod: String, URL: NSURL) throws -> NSURLRequest {
    return try encode(parameters, HTTPMethod: HTTPMethod, URL: URL, encodingType: .URL)
}

private func encode(parameters: [String:AnyObject]?, HTTPMethod: String, URL: NSURL, encodingType: ParameterEncoding) throws -> NSURLRequest {
    
    let mutableURLRequest = NSMutableURLRequest(URL: URL)
    mutableURLRequest.HTTPMethod = HTTPMethod
    
    mutableURLRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    let parameterEncoding = encodingType.encode(mutableURLRequest, parameters: parameters)
    if let error = parameterEncoding.1 {
        throw error
    }
    return parameterEncoding.0
}
