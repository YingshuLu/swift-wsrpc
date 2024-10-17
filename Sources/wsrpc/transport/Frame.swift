//
//  Frame.swift
//  
//
//  Created by yingshu lu on 2023/8/22.
//

import Foundation

enum FrameFlag: UInt8 {
    case next = 8
    case bin = 4
    case rpc = 2
    case ack = 1
}

enum FrameOpcode: UInt8 {
    case stream = 1
    case open = 2
    case close = 3
    case accept = 4
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
    public var payload: Data = Data()
    
    internal var count: Int {
        get {
            let size = payload.count == 0 ? Int(length) : payload.count
            return Frame.FrameHeaderSize + size
        }
    }
    
    static let MagicCode: UInt8 = 0x6f
    static let FrameHeaderSize = 16
    
    init(payload: Data? = nil) {
        if let data = payload {
            self.payload = data
            self.length = UInt32(data.count)
        }
    }
    
    public func toBytes() -> Data {
        var buffer = Data(count: Frame.FrameHeaderSize + Int(self.length))
        buffer[0] = self.magic
        buffer[1] = self.flag
        buffer[2] = self.opcode
        buffer[3] = self.reserved
        
        self.length = UInt32(payload.count)
        Bytes.UInt32ToBytes(value: self.checkSum, bytes: &buffer, start: 4)
        Bytes.UInt16ToBytes(value: self.group, bytes: &buffer, start: 8)
        Bytes.UInt16ToBytes(value: self.index, bytes: &buffer, start: 10)
        Bytes.UInt32ToBytes(value: self.length, bytes: &buffer, start: 12)
        if self.payload.count > 0 {
            buffer.replaceSubrange(16..<buffer.count, with: self.payload)
        }
        return buffer
    }
    
    static func parse(data: Data) -> (ParseCode, Frame?) {
        if data.count < FrameHeaderSize {
            return (ParseCode.needMore, nil)
        }
        if data[0] != MagicCode {
            return (ParseCode.illegal, nil)
        }
        
        let start = data.startIndex
        let frame = Frame()
        frame.magic = data[start]
        frame.flag = data[start+1]
        frame.opcode = data[start+2]
        frame.reserved = data[start+3]
        frame.checkSum = Bytes.toUint32(data: data, start: start+4)
        frame.group = Bytes.toUInt16(data: data, start: start+8)

        frame.index = Bytes.toUInt16(data: data, start: start+10)
        frame.length = Bytes.toUint32(data: data, start: start+12)
        if data.count < frame.count {
            return (.needMore, nil)
        }
        frame.payload = data.subdata(in: start+FrameHeaderSize ..< start+frame.count)
        return (.ok, frame)
    }
}
