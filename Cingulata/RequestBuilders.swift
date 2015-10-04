//
//  RequestBuilders
//  Cingulata
//
//  Created by Alexander Evsyuchenya on 10/3/15.
//  Copyright © 2015 baydet. All rights reserved.
//

import Foundation
import Alamofire

private func encode(parameters: [String:AnyObject]?, HTTPMethod: String, URL: NSURL, encodingType: ParameterEncoding) throws -> NSURLRequest {
    let mutableURLRequest = NSMutableURLRequest(URL: URL)
    mutableURLRequest.HTTPMethod = HTTPMethod
    let parameterEncoding = encodingType.encode(mutableURLRequest, parameters: parameters)
    if let error = parameterEncoding.1 {
        throw error
    }
    return parameterEncoding.0
}

func defaultRequestBuilder(parameters: [String:AnyObject]?, HTTPMethod: String, URL: NSURL) throws -> NSURLRequest {
    return try encode(parameters, HTTPMethod: HTTPMethod, URL: URL, encodingType: .URL)
}

func postRequestBuilder(parameters: [String:AnyObject]?, HTTPMethod: String, URL: NSURL) throws -> NSURLRequest {
    return try encode(parameters, HTTPMethod: HTTPMethod, URL: URL, encodingType: .JSON)
}
