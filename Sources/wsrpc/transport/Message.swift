//
//  Message.swift
//  
//
//  Created by yingshu lu on 2023/8/24.
//

import Foundation

enum RpcParseCode {
    case ok, needMore, illegal
}

enum RpcType: UInt8 {
    case none
    case request
    case reply
    case error
    case unknown
}

class Message {
    var type: UInt8 = 0
    var codec: UInt8 = 0
    var id: UInt32 = 0
    var service: String = ""
    var error: String = ""
    var bytes: Data = Data()
    
    static let MinBufferSize = 12
    
    init(data: Data?) {
        if data != nil {
            self.bytes = data!
        }
    }
    
    func encode() -> Data {
        var bufSize = Message.MinBufferSize + self.service.count
        if self.type == RpcType.error.rawValue {
            bufSize += self.error.count
        } else {
            bufSize += self.bytes.count
        }

        var buffer = Data(count: bufSize)
        var start = buffer.startIndex
        
        buffer[start] = type
        buffer[start+1] = codec
        
        Bytes.UInt32ToBytes(value: self.id, bytes: &buffer, start: start+2)
        
        let serviceLen: UInt16 = UInt16(self.service.count)
        Bytes.UInt16ToBytes(value: serviceLen, bytes: &buffer, start: start+6)
        
        let index = start + 8 + service.count
        buffer.replaceSubrange(8..<index, with: Array(self.service.utf8))
        
        if self.type == RpcType.error.rawValue {
            let errorLen: UInt32 = UInt32(self.error.count)
            Bytes.UInt32ToBytes(value: errorLen, bytes: &buffer, start: index)
            let data: [UInt8] = Array(self.error.utf8)
            buffer.replaceSubrange(index+4..<buffer.count, with: data)
        } else {
            let dataLen: UInt32 = UInt32(self.bytes.count)
            Bytes.UInt32ToBytes(value: dataLen, bytes: &buffer, start: index)
            buffer.replaceSubrange(index+4..<buffer.count, with: self.bytes)
        }
        
        return buffer
    }
    
    static func decode(data: Data) -> (RpcParseCode, Message?) {
        if data.count < Message.MinBufferSize {
            return (RpcParseCode.needMore, nil)
        }
        
        let message = Message(data: nil)
        let start = data.startIndex
        
        message.type = data[start]
        guard message.type > RpcType.none.rawValue && message.type < RpcType.unknown.rawValue else {
            return (RpcParseCode.illegal, nil)
        }
        
        message.codec = data[start+1]
        guard message.codec > SerializerType.none.rawValue && message.codec < SerializerType.unknown.rawValue else {
            return (RpcParseCode.illegal, nil)
        }
        
        message.id = Bytes.toUint32(data: data, start: start+2)
        let serviceLen = Int(Bytes.toUInt16(data: data, start: start+6))
        if data.count < Message.MinBufferSize + serviceLen {
            return (RpcParseCode.needMore, nil)
        }
        
        var index = start + 8 + serviceLen
        if serviceLen > 0 {
            message.service = String(bytes: data[start+8..<index], encoding: .utf8)!
        }
        
        let dataLen = Int(Bytes.toUint32(data: data, start: index))
        if data.count < index + 4 + dataLen {
            return (RpcParseCode.needMore, nil)
        }
        
        index += 4
        if message.type == RpcType.error.rawValue {
            let errString = String(data: data[index...], encoding: .ascii)
            message.error = errString ?? "null"
        } else {
            let bytes = data[index...]
            message.bytes = bytes
        }
        return (RpcParseCode.ok, message)
    }
    
    static func replyError(id: UInt32, error: String) -> Message {
        let message = Message(data: nil)
        message.id = id
        message.type = RpcType.error.rawValue
        message.error = error
        return message
    }
    
}
