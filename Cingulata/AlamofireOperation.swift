//
//  AlamofireOperation.swift
//  Cingulata
//
//  Created by Alexander Evsyuchenya on 10/3/15.
//  Copyright © 2015 baydet. All rights reserved.
//

import Foundation
import Alamofire

class AlamofireOperation: Operation {
    let urlRequest : NSURLRequest
    private var request : Request?
    internal private(set) var statusCode: Int?
    internal private(set) var responseJSON : AnyObject?
    private let manager: Manager
    let taskType: TaskType

    init(request: NSURLRequest, taskType: TaskType, manager: Manager?) {
        self.urlRequest = request
        self.manager = manager ?? Manager.sharedInstance
        self.taskType = taskType
        super.init()
    }

    override func execute() {

        switch taskType {
        case .DataTask:
            request = manager.request(urlRequest)
        case .DownloadFile(let destination):
            request = manager.download(urlRequest, destination: destination)
        case .UploadData:
            request = manager.upload(urlRequest, data: urlRequest.HTTPBody ?? NSData(bytes: nil, length: 0))
        case .UploadFile(let fileURL):
            request = manager.upload(urlRequest, file: fileURL)
        }
        
        request?.response() { [unowned self]  request, response, data, error in
            self.statusCode = response?.statusCode
            if let error = error {
                self.errors.append(error)
            }
            if let data = data {
                self.responseJSON = try? NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
            }
            
            self.finish()
        }

    }

    override func cancel() {
        request?.cancel()
        super.cancel()
    }
}