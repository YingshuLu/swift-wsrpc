//
//  File.swift
//  
//
//  Created by yingshu lu on 2023/8/22.
//

import XCTest
@testable import wsrpc

final class FrameTests: XCTestCase {
    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        let frame = Frame(payload: [0x12, 0x34])
        frame.flag = 1
        frame.checkSum = 655360

        var data = frame.toBytes()
        XCTAssertTrue(data.count == 18)
        
        let (code, f) = Frame.Parse(data: &data)
        XCTAssertTrue(code == ParseCode.ok)
        XCTAssertTrue(f?.flag == frame.flag)
        XCTAssertTrue(f?.checkSum == frame.checkSum)
    }
}

