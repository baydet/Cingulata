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

enum Endpoint: RequestBuilder {
    
    case NotFound
    
    var URL: NSURL {
        let path: String!
        switch self {
        case .NotFound:
            path = "notFound"
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
        return nil
    }
    var requestMapping: RequestObjectMapping? {
        return nil
    }
    var requestBuilder: NSURLRequestBuilder {
        return defaultRequestBuilder
    }
    var responseMapping: [ResponseObjectMapping]? {
        return nil
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
