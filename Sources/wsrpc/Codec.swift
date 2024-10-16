//
//  Codec.swift
//
//
//  Created by yingshulu on 2024/10/16.
//

import Foundation
import SwiftProtobuf

public enum SerializerType: Int {
    case protobuf
    case json
}

class Codec {
    public static func toBytes(message: SwiftProtobuf.Message, type: SerializerType) throws -> Data {
        switch type {
        case .json:
            return try message.jsonUTF8Data()
            
        case .protobuf:
            return try message.serializedData()
            
        default:
            throw RpcProxyError.SerializeError("Codec.toBytes - not support type \(type)")
        }
    }
    
    public static func toMessage<T:SwiftProtobuf.Message>(data: Data, type: SerializerType) throws -> T {
        switch type {
        case .json:
            return try T(jsonUTF8Data: data)
            
        case .protobuf:
            return try T(serializedData: data)
            
        default:
            throw RpcProxyError.SerializeError("Codec.toMessage - not support type \(type)")
        }
    }
}
