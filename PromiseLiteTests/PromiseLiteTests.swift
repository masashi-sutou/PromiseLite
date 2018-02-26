//
//  PromiseLiteTests.swift
//  PromiseLiteTests
//
//  Created by 須藤将史 on 2018/02/26.
//
//  Copyright © 2015年 yashigani. All rights reserved.
//  Copyright © 2018年 須藤将史. All rights reserved.
//

import XCTest
@testable import PromiseLite

class PromiseLiteTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testPerformanceExample() {
        self.measure {
        }
    }
    
    // MARK: - PromiseLite Class Test
    
    enum DummyError: Error {
        typealias RawValue = Int
        case any
    }
    
    func testResolve() {
        let p = PromiseLite.resolve(value: 1)
        XCTAssert(p.state == .resolved)
        if case .value(let value) = p.result {
            XCTAssert(value == 1)
        } else {
            XCTFail()
        }
    }
    
    func testReject() {
        let p = PromiseLite<Int>.reject(error: DummyError.any)
        XCTAssert(p.state == .rejected)
        if case .error(let e as DummyError) = p.result {
            XCTAssert(e == .any)
        } else {
            XCTFail()
        }
    }
    
    func testResolved() {
        let exp = expectation(description: "promiseLite.resolve")
        let p = PromiseLite<Int> { resolve, _ in
            resolve(1)
            exp.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssert(p.state == .resolved)
        if case .value(let value) = p.result {
            XCTAssert(value == 1)
        } else {
            XCTFail()
        }
    }
    
    func testRejected() {
        let exp = expectation(description: "promiseLite.reject")
        let p = PromiseLite<Int> { _, reject in
            reject(DummyError.any)
            exp.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssert(p.state == .rejected)
        if case .error(let e as DummyError) = p.result {
            XCTAssert(e == .any)
        } else {
            XCTFail()
        }
    }
    
    func testInitializePromiseLiteWithOtherPromiseLite() {
        let p = PromiseLite<Int> { resolve, _ in
            sleep(3)
            resolve(1)
        }
        let p2 = PromiseLite(p)
        XCTAssert(p2.state == .resolved)
        if case .value(let value) = p2.result {
            XCTAssert(value == 1)
        } else {
            XCTFail()
        }
    }
    
    func testInitializePromiseLiteWithAutoclosure() {
        let json = "{\"written_by\": \"masashi_sutou\"}".data(using: String.Encoding.utf8)!
        var exp = expectation(description: "success")
        let p1 = PromiseLite(try JSONSerialization.jsonObject(with: json, options: []))
        p1.then { v in
            if let v = v as? [String : String] {
                XCTAssert(v == ["written_by": "masashi_sutou"])
            } else {
                XCTFail()
            }
            exp.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssert(p1.state == .resolved)
        
        let brokenJson = "{\"written_by\": \"masashi_sutou\"".data(using: String.Encoding.utf8)!
        exp = expectation(description: "failure")
        let p2 = PromiseLite(try JSONSerialization.jsonObject(with: brokenJson, options: []))
        p2.catchError { _ in
            exp.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssert(p2.state == .rejected)
    }
    
    func testThen() {
        let exp = expectation(description: "promiseLite.then")
        let p = PromiseLite.resolve(value: 1).then { v in v * 2 }
        p.then { _ -> () in
            exp.fulfill()
        }
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssert(p.state == .resolved)
        if case .value(let value) = p.result {
            XCTAssert(value == 2)
        } else {
            XCTFail()
        }
    }
    
    func testcatchError() {
        let exp = expectation(description: "promiseLite.catchError")
        let p = PromiseLite<Int>.reject(error: DummyError.any).catchError { e in
            switch e {
            case DummyError.any:
                exp.fulfill()
            default:
                XCTFail()
            }
        }
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssert(p.state == .rejected)
        if case .error(let e as DummyError) = p.result {
            XCTAssert(e == .any)
        } else {
            XCTFail()
        }
    }
    
    func testPromiseLiteComposition() {
        
        // sample code in README.md
        
        func increment(v: Int) -> Int { return v + 1 }
        func doubleUp(v: Int) -> Int { return v * 2 }
        
        let exp = expectation(description: "promiseLite.composition")
        let p = PromiseLite.resolve(value: 10)
            .then(onResolved: increment)
            .then(onResolved: doubleUp)
            .then { v in
                XCTAssert(v == 22)
                exp.fulfill()
            }.catchError { _ in XCTFail() }
        
        waitForExpectations(timeout: 1, handler: nil)
        XCTAssert(p.state == .resolved)
    }
    
    func testAll() {
        func timer(second: UInt32) -> PromiseLite<UInt32> {
            return PromiseLite { resolve, _ in
                sleep(second)
                resolve(second)
            }
        }
        
        var exp = expectation(description: "promiseLite.all")
        let p1 = PromiseLite.all(promiseLites: [timer(second: 1), timer(second: 2), timer(second: 3)]).then { v in
            XCTAssert(v == [1, 2, 3])
            exp.fulfill()
        }
        waitForExpectations(timeout: 5, handler: nil)
        XCTAssert(p1.state == .resolved)
        
        exp = expectation(description: "promiseLite.all")
        let p2 = PromiseLite<UInt32> { _, reject in
            sleep(1)
            reject(DummyError.any)
        }
        
        let p3 = PromiseLite.all(promiseLites: [timer(second: 1), timer(second: 2), timer(second: 3), p2]).then { _ in
            XCTFail()
            }.catchError { e in
                switch e {
                case DummyError.any:
                    ()
                default:
                    XCTFail()
                }
                exp.fulfill()
        }
        waitForExpectations(timeout: 5, handler: nil)
        XCTAssert(p3.state == .rejected)
    }
    
    func testRace() {
        let p1 = PromiseLite<Int> { resolve, _ in
            sleep(1)
            resolve(1)
        }
        let p2 = PromiseLite<Int> { resolve, _ in
            sleep(2)
            resolve(2)
        }
        
        PromiseLite<Int>.race(promiseLites: [p1, p2]).then { v in
            XCTAssert(v == 1)
        }
        
        let p3 = PromiseLite<Int> { resolve, _ in
            sleep(1)
            resolve(1)
        }
        let p4 = PromiseLite<Int> { _, reject in
            sleep(2)
            reject(DummyError.any)
        }
        
        PromiseLite<Int>.race(promiseLites: [p3, p4]).then { v in
            XCTAssert(v == 1)
            }.catchError { _ in
                XCTFail()
        }
        
        let p5 = PromiseLite<Int> { resolve, _ in
            sleep(2)
            resolve(1)
        }
        let p6 = PromiseLite<Int> { _, reject in
            sleep(1)
            reject(DummyError.any)
        }
        
        PromiseLite<Int>.race(promiseLites: [p5, p6]).then { _ in
            XCTFail()
        }.catchError { e in
            switch e {
            case DummyError.any:
                ()
            default:
                XCTFail()
            }
        }
    }
}
