//
//  Codec.swift
//
//
//  Created by yingshulu on 2024/10/16.
//

import Foundation
import SwiftProtobuf

public enum SerializerType: Int {
    case none
    case protobuf
    case json
}

class Codec {
    public static func encode(message: SwiftProtobuf.Message, type: SerializerType) throws -> Data {
        do {
            switch type {
            case .json:
                return try message.jsonUTF8Data()
                
            case .protobuf:
                return try message.serializedData()
                
            default:
                throw RpcProxyError.SerializeError("\(type) serialization not supported")
            }
        } catch let error {
            throw RpcProxyError.SerializeError("wsrpc library: \(type) encode throws \(error)")
        }
    }
    
    public static func decode<T:SwiftProtobuf.Message>(data: Data, type: SerializerType) throws -> T {
        do {
            switch type {
            case .json:
                return try T(jsonUTF8Data: data)
                
            case .protobuf:
                return try T(serializedData: data)
                
            default:
                throw RpcProxyError.SerializeError("\(type) serialization not supported")
            }
        } catch let error {
            throw RpcProxyError.SerializeError("wsrpc library: \(type) decode throws \(error)")
        }
    }
}
