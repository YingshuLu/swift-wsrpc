//
//  Bytes.swift
//  
//
//  Created by yingshu lu on 2023/8/24.
//

import Foundation

struct Bytes {
    static func toUint32(data: Data, start: Int) -> UInt32 {
        return UInt32(data[start]) << 24 |
                UInt32(data[start+1]) << 16 |
                UInt32(data[start+2]) << 8 |
                UInt32(data[start+3])
    }
    
    static func toUInt16(data: Data, start: Int) -> UInt16 {
        return UInt16(data[0]) << 8 | UInt16(data[start+1])
    }
    
    static func UInt32ToBytes(value: UInt32, bytes: inout Data, start: Int) {
        let mask: UInt32 = 255
        bytes[start] = UInt8((value >> 24) & mask)
        bytes[start+1] = UInt8((value >> 16) & mask)
        bytes[start+2] = UInt8((value >> 8) & mask)
        bytes[start+3] = UInt8(value & mask)
    }
    
    static func UInt16ToBytes(value: UInt16, bytes: inout Data, start: Int) {
        let mask: UInt16 = 255
        bytes[start] = UInt8((value >> 8) & mask)
        bytes[start+1] = UInt8(value & mask)
    }
}
