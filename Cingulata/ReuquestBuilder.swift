//
//  RequestBuilder
//  Cingulata
//
//  Created by Alexander Evsyuchenya on 10/3/15.
//  Copyright © 2015 baydet. All rights reserved.
//

import Foundation
import Alamofire
import Pichi

public enum TaskType {
    case DataTask
    case UploadData
    case UploadFile(NSURL)
    case DownloadFile(Request.DownloadFileDestination)
    //todo resumeDownload
}

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
    var requestTaskType: TaskType { get }
    var manager: Manager? { get }
}

public extension RequestOperation {
    public convenience init(requestBuilder: RequestBuilder) {
        self.init(requestMethod     : requestBuilder.httpMethod,
                  parameters        : requestBuilder.parameters,
                  requestBuilder    : requestBuilder.requestBuilder,
                  requestMapping    : requestBuilder.requestMapping,
                  responseMappings  : requestBuilder.responseMapping,
                  URL               : requestBuilder.URL,
                  taskType          : requestBuilder.requestTaskType,
                  manager           : requestBuilder.manager
        )
    }
}