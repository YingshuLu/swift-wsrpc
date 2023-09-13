//
//  File.swift
//  
//
//  Created by yingshu lu on 2023/8/24.
//

import Foundation

struct Bytes {
    static func ToUint32(bytes: inout [UInt8], start: Int) -> UInt32 {
        return UInt32(bytes[start]) << 24 |
                UInt32(bytes[start+1]) << 16 |
                UInt32(bytes[start+2]) << 8 |
                UInt32(bytes[start+3])
    }
    
    static func ToUInt16(bytes: inout [UInt8], start: Int) -> UInt16 {
        return UInt16(bytes[start]) << 8 | UInt16(bytes[start+1])
    }
    
    static func UInt32ToBytes(value: UInt32, bytes: inout [UInt8], start: Int) {
        let mask: UInt32 = 255
        bytes[start] = UInt8((value >> 24) & mask)
        bytes[start+1] = UInt8((value >> 16) & mask)
        bytes[start+2] = UInt8((value >> 8) & mask)
        bytes[start+3] = UInt8(value & mask)
    }
    
    static func UInt16ToBytes(value: UInt16, bytes: inout [UInt8], start: Int) {
        let mask: UInt16 = 255
        bytes[start] = UInt8((value >> 8) & mask)
        bytes[start+1] = UInt8(value & mask)
    }
}
