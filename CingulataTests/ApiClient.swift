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
import ObjectMapper

struct TestData: Mappable {
    var stringKey: String = ""
    var string2Key: String = ""
    
    init() {
    }
    
    init?(_ map: Map) {
        self = TestData()
    }
    
    mutating func mapping(map: Map) {
        stringKey <- map["key"]
        string2Key <- map["key2"]
    }
}

struct NestedData: Mappable {
    var stringKey: String = ""
    
    init() {
    }
    
    init?(_ map: Map) {
        self = NestedData()
    }
    
    mutating func mapping(map: Map) {
        stringKey <- map["Host"]
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
            return (nil, DefaultMapper<TestData>(sourceObject: SourceObjectType<TestData>.Object(data), expectedResultType: .Object))
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
            return [(HTTPStatusCodeGroup.Success(nil), nil, DefaultMapper<TestData>(expectedResultType: .Object))]
        case .GetNestedData:
            return [(HTTPStatusCodeGroup.Success(nil), "headers", DefaultMapper<NestedData>(expectedResultType: .Object))]
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
