//
//  frame.swift
//  
//
//  Created by yingshu lu on 2023/8/22.
//

import Foundation

enum FrameFlag: UInt8 {
    case NextFlag = 8
    case BinFlag = 4
    case RpcFlag = 2
    case AckFlag = 1
}

enum FrameOpcode: UInt8 {
    case Open = 1
    case Accept = 2
    case Stream = 3
    case Finish = 4
}

enum ParseCode {
    case ok, needMore, illegal
}

public class Frame {
    public var magic: UInt8 = Frame.MagicCode
    public var flag:  UInt8 = 0
    public var opcode: UInt8 = 0
    public var reserved: UInt8 = 0
    public var checkSum: UInt32 = 0
    public var group: UInt16 = 0
    public var index: UInt16 = 0
    public var length: UInt32 = 0
    public var payload: [UInt8]?
    
    static let MagicCode: UInt8 = 0x6f
    static let FrameHeaderSize = 16
    
    init(payload: [UInt8]?) {
        self.payload = payload
        self.length = UInt32(self.payload?.count ?? 0)
    }
    
    public func toBytes() -> [UInt8] {
        var buffer = [UInt8](repeating: 0, count: Frame.FrameHeaderSize + Int(self.length))
        buffer[0] = self.magic
        buffer[1] = self.flag
        buffer[2] = self.opcode
        buffer[3] = self.reserved
        
        self.length = UInt32(payload?.count ?? 0)
        Bytes.UInt32ToBytes(value: self.checkSum, bytes: &buffer, start: 4)
        Bytes.UInt16ToBytes(value: self.group, bytes: &buffer, start: 8)
        Bytes.UInt16ToBytes(value: self.index, bytes: &buffer, start: 10)
        Bytes.UInt32ToBytes(value: self.length, bytes: &buffer, start: 12)
        buffer.replaceSubrange(16..<buffer.count, with: self.payload!)
        return buffer
    }
    
    static func Parse(data: inout [UInt8]) -> (ParseCode, Frame?) {
        if data.count < FrameHeaderSize {
            return (ParseCode.needMore, nil)
        }
        if data[0] != MagicCode {
            return (ParseCode.illegal, nil)
        }
        
        let frame = Frame(payload: nil)
        frame.magic = data[0]
        frame.flag = data[1]
        frame.opcode = data[2]
        frame.reserved = data[3]
        frame.checkSum = Bytes.ToUint32(bytes: &data, start: 4)
        frame.group = Bytes.ToUInt16(bytes: &data, start: 8)
        frame.index = Bytes.ToUInt16(bytes: &data, start: 10)
        frame.length = Bytes.ToUint32(bytes: &data, start: 12)
        if data.count < FrameHeaderSize + Int(frame.length) {
            return (ParseCode.needMore, nil)
        }
        frame.payload = Array(data[16..<data.count])
        return (ParseCode.ok, frame)
    }
}
