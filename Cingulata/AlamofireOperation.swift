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