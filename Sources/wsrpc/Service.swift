//
//  Service.swift
//  
//
//  Created by yingshulu on 2023/8/30.
//

import Foundation
import SwiftProtobuf

internal protocol InternalService {
    var name: String { get }
    var options: Options { get }
    func invokeInternal(requestMessage: Message) -> Message
}

open class Service<T:SwiftProtobuf.Message, U:SwiftProtobuf.Message>: InternalService {
    private enum internalError: Error {
        case notImplement(String)
    }
    
    var name: String
    
    var options = Options()
    
    public init(name: String) {
        self.name = name
    }
   
    open func serve(request: T) throws -> U {
        throw internalError.notImplement("service \(self.name) not implement")
    }
    
    internal func invokeInternal(requestMessage: Message) -> Message {
        let replyMessage = Message(data: nil)
        replyMessage.id = requestMessage.id
        
        do {
            let request: T = try Codec.decode(data: Data(requestMessage.bytes), type: self.options.serializer)
            let reply = try serve(request: request)
            replyMessage.type = RpcType.reply.rawValue
            replyMessage.bytes = try Codec.encode(message: reply, type: self.options.serializer)
        } catch let error {
            replyMessage.type = RpcType.error.rawValue
            replyMessage.error = error.localizedDescription
        }
        return replyMessage
    }
}
