//
//  Service.swift
//  
//
//  Created by yingshulu on 2023/8/30.
//

import Foundation
import SwiftProtobuf

@available(macOS 11.0, *)
internal protocol InternalService {
    var name: String { get }
    var options: Options { get }
    func invokeInternal(requestMessage: Message) -> Message
}

@available(macOS 11.0, *)
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
        
        guard let codec = SerializerType(rawValue: requestMessage.codec) else {
            replyMessage.type = RpcType.error.rawValue
            replyMessage.error = "codec type \(requestMessage.codec) no supported"
            return replyMessage
        }
        
        do {
            let request: T = try Codec.decode(data: Data(requestMessage.bytes), type: codec)
            let reply = try serve(request: request)
            replyMessage.type = RpcType.reply.rawValue
            replyMessage.bytes = try Codec.encode(message: reply, type: codec)
        } catch let error {
            replyMessage.type = RpcType.error.rawValue
            replyMessage.error = error.localizedDescription
        }
        return replyMessage
    }
}
