//
//  Proxy.swift
//  
//
//  Created by yingshulu on 2023/8/30.
//

import Foundation
import SwiftProtobuf
import os

@available(iOS 14.0, macOS 11.0, *)
public class Proxy {
    private let name: String
    private let connection: Connection
    private let options: Options
    private let logger = Logger(subsystem: "com.bulo.wsrpc", category: "Proxy")
    
    init(name: String, connection: Connection, options: Options) {
        self.name = name
        self.connection = connection
        self.options = options
    }
    
    public func call<T:SwiftProtobuf.Message, U:SwiftProtobuf.Message>(request: T) throws -> U {
        let requestData = try Codec.encode(message: request, type: options.serializer)
        
        let replyMessage = try self.connection.call(name: self.name, requestData: requestData, options: self.options)
        if replyMessage.type == RpcType.error.rawValue {
            logger.error("reply error: \(replyMessage.error)")
            throw RpcProxyError.ServiceError(replyMessage.error)
        }
        
        let reply: U = try Codec.decode(data: replyMessage.bytes, type: options.serializer)
        return reply
    }
}

@available(macOS 11.0, *)
public extension Connection {
    func getProxy(name: String, options: Option...) -> Proxy {
        let newOptions = self.options.clone()
        newOptions.apply(options: options)
        return Proxy(name: name, connection: self, options: newOptions)
    }
}
