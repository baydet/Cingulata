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

/// function for creating NSURLRequest
public typealias NSURLRequestBuilder = (parameters: [String:AnyObject]?, HTTPMethod: String, URL: NSURL) throws -> NSURLRequest

public typealias CleanOrhpanedObjects = () -> Void

/**
 *  Protocol declares main parts of what final RequestOperation should consist of
 */
public protocol RequestBuilder {
    /// URL for the resource
    var URL: NSURL { get }
    var httpMethod: Method { get }
    var parameters: [String : AnyObject]? { get }
    var requestMapping: RequestObjectMapping? { get }
    var requestBuilder: NSURLRequestBuilder { get }
    var responseMapping: [ResponseObjectMapping]? { get }
    var cleanOrphanedObjects: CleanOrhpanedObjects? { get }
}
