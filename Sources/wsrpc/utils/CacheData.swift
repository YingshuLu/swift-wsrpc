//
//  CacheData.swift
//  wsrpc
//
//  Created by yingshulu on 2024/10/23.
//

import Foundation
import os

public class CacheData {
    private var locker: NSLock?
    
    private var queue = Queue<Data>()
    
    var count = 0
    
    var isEmpty: Bool {
        return count == 0
    }
    
    init(sync: Bool = false) {
        if sync {
            self.locker = NSLock()
        }
    }
    
    func write(data: Data) {
        locker?.lock()
        defer { locker?.unlock() }
        
        if data.isEmpty {
            return
        }
        
        count += data.count
        queue.push(data)
    }
    
    func read(expected: Int) -> Data? {
        locker?.lock()
        defer { locker?.unlock() }
        
        guard expected > 0 && count > expected else {
            return nil
        }
        
        var data = Data()
        var left = expected
        while let node = queue.firstNode {
            if node.value.count <= left {
                if data.isEmpty {
                    data = node.value
                } else {
                    data.append(node.value)
                }
                left -= node.value.count
                let _ = queue.pop()
            } else {
                let start = node.value.startIndex
                let pos = start + left
                let end = node.value.endIndex
                let subdata = node.value.subdata(in: start ..< pos)
                if data.isEmpty {
                    data = subdata
                } else {
                    data.append(subdata)
                }
                node.value = node.value.subdata(in: pos ..< end)
                left = 0
            }

            if left == 0 {
                break
            }
        }
        
        count -= data.count
        return data
    }
    
    func peek(expected: Int) -> Data? {
        locker?.lock()
        defer { locker?.unlock() }
        
        var nodeItem = queue.firstNode
        guard expected > 0 && count > expected && nodeItem != nil else {
            return nil
        }
        
        var data = Data()
        var left = expected
        while let node = nodeItem {
            if node.value.count <= left {
                if data.isEmpty {
                    data = node.value
                } else {
                    data.append(node.value)
                }
                left -= node.value.count
                nodeItem = node.next
            } else {
                let start = node.value.startIndex
                let subdata = node.value.subdata(in: start ..< start + left)
                if data.isEmpty {
                    data = subdata
                } else {
                    data.append(subdata)
                }
                left = 0
            }
            
            if left == 0 {
                break
            }
        }
        
        return data
    }
}
