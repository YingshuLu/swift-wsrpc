//
//  Bytes.swift
//  
//
//  Created by yingshu lu on 2023/8/24.
//

import Foundation

struct Bytes {
    static func toUint32(data: Data, start: Int) -> UInt32 {
        let subdata = data.subdata(in: start ..< start+4)
        return subdata.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
    }
    
    static func toUInt16(data: Data, start: Int) -> UInt16 {
        let subdata = data.subdata(in: start ..< start+2)
        return subdata.withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
    }
    
    static func UInt32ToBytes(value: UInt32, bytes: inout Data, start: Int) {
        let bigEndianValue = value.bigEndian
        withUnsafeBytes(of: bigEndianValue) { buffer in
            for (index, byte) in buffer.enumerated() {
                bytes[start+index] = byte
            }
        }
    }
    
    static func UInt16ToBytes(value: UInt16, bytes: inout Data, start: Int) {
        let bigEndianValue = value.bigEndian
        withUnsafeBytes(of: bigEndianValue) { buffer in
            for (index, byte) in buffer.enumerated() {
                bytes[start+index] = byte
            }
        }
    }
}
