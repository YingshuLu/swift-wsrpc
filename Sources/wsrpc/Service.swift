//
//  Service.swift
//  
//
//  Created by yingshulu on 2023/8/30.
//

import Foundation
import SwiftProtobuf

protocol InternalService {
    var name: String { get }
    func invokeInternal(requestMessage: Message) -> Message
}

public class Service<T:SwiftProtobuf.Message, U:SwiftProtobuf.Message>: InternalService {
    private enum internalError: Error {
        case notImplement(String)
    }
    
    var name: String
    
    public init(name: String) {
        self.name = name
    }
   
    public func Serve(request: T) throws -> U {
        throw internalError.notImplement("service \(self.name) not implement")
    }
    
    func invokeInternal(requestMessage: Message) -> Message {
        let replyMessage = Message(data: nil)
        replyMessage.id = requestMessage.id
        
        do {
            let request = try parseRequest(data: requestMessage.Data!)
            let reply = try Serve(request: request)
            let data = try reply.serializedData()
            replyMessage.type = RpcType.reply.rawValue
            replyMessage.Data = [UInt8](data)
        } catch {
            replyMessage.type = RpcType.error.rawValue
            replyMessage.error = error.localizedDescription
        }
        return replyMessage
    }
    
    private func parseRequest(data: [UInt8]) throws -> T {
        let request = try T(serializedData: Data(data))
        return request
    }
    
}
