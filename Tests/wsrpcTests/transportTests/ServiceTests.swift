//
//  File.swift
//  
//
//  Created by yingshulu on 2023/9/1.
//

import XCTest
import os
@testable import wsrpc

final class ServiceTests: XCTestCase {
    func testExample() throws {
        do {
            let echoClient = Client(host: "echo_client")
            _ = try echoClient.connect(wsUrl: "ws://localhost:9090/websocket", provider: nil)
            sleep(30)
            echoClient.close()
        } catch RpcProxyError.ServiceError(let message){
            print("echo client error \(message)")
            XCTAssertTrue(false)
        }
        
    }
}
