//
//  Transport.swift
//  
//
//  Created by yingshu lu on 2023/8/23.
//

import Foundation

protocol Transport {
    func read() throws -> Frame
    func write(frame: Frame) throws
    func close() throws
}
