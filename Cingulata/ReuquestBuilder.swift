//
//  RequestBuilder
//  Cingulata
//
//  Created by Alexander Evsyuchenya on 10/3/15.
//  Copyright © 2015 baydet. All rights reserved.
//

import Foundation
import Alamofire
import ObjectMapper

public protocol RequestBuilder {
    var URL: NSURL { get }
    var httpMethod: Alamofire.Method { get }
    var parameters: [String : AnyObject]? { get }
    var requestMapping: RequestObjectMapping? { get }
    var requestBuilder: NSURLRequestBuilder { get }
    var responseMapping: [ResponseObjectMapping]? { get }
}

public extension RequestOperation {
    public convenience init(requestBuilder: RequestBuilder) {
        self.init(requestMethod: requestBuilder.httpMethod, parameters: requestBuilder.parameters, requestBuilder: requestBuilder.requestBuilder, requestMapping: requestBuilder.requestMapping, responseMappings: requestBuilder.responseMapping, URL: requestBuilder.URL)
    }
}