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
            let connection = try echoClient.connect(wsUrl: "ws://localhost:9000/ws/broker", timeoutSeconds: 3, provider: nil)
            XCTAssertTrue(connection.peer.count > 0)
            print("connection connected \(connection.peer)")
            sleep(3)
            
            echoClient.close()
        } catch RpcProxyError.ServiceError(let message){
            print("echo client error \(message)")
            XCTAssertTrue(false)
        }
        
    }
}
