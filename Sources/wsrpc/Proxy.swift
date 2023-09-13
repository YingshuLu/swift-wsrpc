//
//  Proxy.swift
//  
//
//  Created by yingshulu on 2023/8/30.
//

import Foundation
import SwiftProtobuf

enum RpcProxyError: Error {
    case ServiceError(String)
}

public typealias Option = (Options) -> Void

public class Options {
    var RpcTimeout: UInt64 = 0
    
    var RoundTripTimeout: UInt64 = 0
    
    func apply(options: [Option]) {
        for f in options {
            f(self)
        }
    }
    
    public static func withRpcTimeout(timeout: UInt64) -> Option {
        return { options in
            options.RpcTimeout = timeout
        }
    }
}

@available(iOS 14.0, macOS 11.0, *)
public class Proxy {

    private var options = Options()
    
    private var connection: Connection
    
    private let name: String
    
    init(name: String, connection: Connection, options: [Option]) {
        self.name = name
        self.connection = connection
        self.options.apply(options: options)
    }
    
    public func Call<T:SwiftProtobuf.Message, U:SwiftProtobuf.Message>(request: T) throws -> U {
        let requestData = try request.serializedData()
        let replyMessage = try self.connection.call(name: self.name, requestData: [UInt8](requestData), options: self.options)
        
        if replyMessage.type == RpcType.error.rawValue {
            print("reply error: \(replyMessage.error)")
            throw RpcProxyError.ServiceError(replyMessage.error)
        }
        
        let reply = try U(serializedData: Data(replyMessage.Data!))
        return reply
    }
    
}

@available(macOS 11.0, *)
public extension Connection {
    func getProxy(name: String, options: Option...) -> Proxy {
        return Proxy(name: name, connection: self, options: options)
    }
}
