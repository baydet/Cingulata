//
//  RequestOperationTests.swift
//  Cingulata
//
//  Created by Alexandr Evsyuchenya on 11/16/15.
//  Copyright © 2015 Alexander Evsyuchenya. All rights reserved.
//

import XCTest
@testable import Cingulata

class RequestOperationTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testFailureBlock() {
        let expectation = expectationWithDescription("GET request should return 404")
        let operation = RequestOperation(requestBuilder: Endpoint.NotFound)
        var errors: [RequestError] = []
        operation.errorBlock = { _errors in
            errors = _errors
            expectation.fulfill()
        }
        operation.successBlock = { results in
            print(results)
        }
        operation.start()
        waitForExpectationsWithTimeout(10, handler: nil)
        
        XCTAssertEqual(errors.count, 1)
        let error = errors.first!
        switch error {
        case .HTTPRequestError(let group, _):
            XCTAssertEqual(group.statusCode, HTTPStatusCode.NotFound)
        default:
            XCTAssertFalse(false, "wrong error type")
        }
    }
    
}

extension HTTPStatusCodeGroup {
    var statusCode: HTTPStatusCode? {
        switch self {
        case .Client(let group):
            return group
        default:
            return nil
        }
    }
}
