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

enum RpcType: UInt16 {
    case none = 0
    case request = 1
    case reply = 2
    case error = 3
    case close = 4
}

class Message {
    var type: UInt16 = RpcType.none.rawValue
    var id: UInt32 = 0
    var service: String = ""
    var error: String = ""
    var Data: [UInt8]?
    
    static let MinBufferSize = 12
    
    init(data: [UInt8]?) {
        self.Data = data
    }
    
    func Encode() -> [UInt8] {
        var bufSize = Message.MinBufferSize + self.service.count
        if self.type == RpcType.error.rawValue {
            bufSize += self.error.count
        } else {
            bufSize += self.Data?.count ?? 0
        }

        var buffer = [UInt8](repeating: 0, count: bufSize)
        Bytes.UInt16ToBytes(value: self.type, bytes: &buffer, start: 0)
        Bytes.UInt32ToBytes(value: self.id, bytes: &buffer, start: 2)
        let serviceLen: UInt16 = UInt16(self.service.count)
        Bytes.UInt16ToBytes(value: serviceLen, bytes: &buffer, start: 6)
        
        let index = 8 + Int(serviceLen)
        buffer.replaceSubrange(8..<index, with: Array(self.service.utf8))
        
        if self.type == RpcType.error.rawValue {
            let errorLen: UInt32 = UInt32(self.error.count)
            Bytes.UInt32ToBytes(value: errorLen, bytes: &buffer, start: index)
            let data: [UInt8] = Array(self.error.utf8)
            buffer.replaceSubrange(index+4..<buffer.count, with: data)
        } else {
            let dataLen: UInt32 = UInt32(self.Data?.count ?? 0)
            Bytes.UInt32ToBytes(value: dataLen, bytes: &buffer, start: index)
            buffer.replaceSubrange(index+4..<buffer.count, with: self.Data!)
        }
        return buffer
    }
    
    static func Decode(data: inout [UInt8]) -> (RpcParseCode, Message?) {
        if data.count < Message.MinBufferSize {
            return (RpcParseCode.needMore, nil)
        }
        
        let message = Message(data: nil)
        message.type = Bytes.ToUInt16(bytes: &data, start: 0)
        if message.type <= RpcType.none.rawValue || message.type > RpcType.error.rawValue {
            return (RpcParseCode.illegal, nil)
        }
        
        message.id = Bytes.ToUint32(bytes: &data, start: 2)
        let serviceLen = Int(Bytes.ToUInt16(bytes: &data, start: 6))
        if data.count < Message.MinBufferSize + serviceLen {
            return (RpcParseCode.needMore, nil)
        }
        
        var index = 8 + serviceLen
        if serviceLen > 0 {
            message.service = String(bytes: data[8..<index], encoding: .utf8)!
        }
        
        let dataLen = Int(Bytes.ToUint32(bytes: &data, start: index))
        if data.count < index + 4 + dataLen {
            return (RpcParseCode.needMore, nil)
        }
        
        index += 4
        if message.type == RpcType.error.rawValue {
            message.error = String(bytes: Array(data[index...]), encoding: .utf8)!
        } else {
            let bytes = Array(data[index...])
            message.Data = bytes
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
