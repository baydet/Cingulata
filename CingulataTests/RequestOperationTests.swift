//
//  RequestOperationTests.swift
//  Cingulata
//
//  Created by Alexandr Evsyuchenya on 11/16/15.
//  Copyright © 2015 Alexander Evsyuchenya. All rights reserved.
//

import XCTest
import Cingulata

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
            XCTAssertEqual(group, HTTPStatusCode.NotFound)
        default:
            XCTAssertFalse(false, "wrong error type")
        }
    }
    
    func testSuccesMappingBlock() {
        let expectation = expectationWithDescription("GET request should return 200 with non empty response")
        var data = TestData()
        data.stringKey = "value"
        let endpoint = Endpoint.Data(object: data)
        let operation = RequestOperation(requestBuilder: endpoint)
        var object: TestData? = nil
        operation.errorBlock = { _errors in
            expectation.fulfill()
        }
        operation.successBlock = { results in
            object = (results.flatMap {$0 as? TestData}).first
            expectation.fulfill()
        }
        operation.start()
        waitForExpectationsWithTimeout(5, handler: nil)
        
        XCTAssertNotNil(object)
        XCTAssertEqual(object?.stringKey, data.stringKey)
        XCTAssertEqual(object?.string2Key, endpoint.parameters?.values.first as? String)
    }
    
}