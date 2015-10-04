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

    init(request: NSURLRequest) {
        self.urlRequest = request
        super.init()
    }

    override func execute() {

        request = Alamofire.request(urlRequest)
        request?.responseJSON() { [unowned self]  response  in
            self.statusCode = response.response?.statusCode
            switch response.result {
            case .Success(let value):
                self.responseJSON = value
            default:
                break;
            }

            self.finish()
        }

    }

    override func cancel() {
        request?.cancel()
        super.cancel()
    }
}