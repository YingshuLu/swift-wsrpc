//
//  BlockingQueue.swift
//  
//
//  Created by yingshulu on 2023/8/31.
//

import Foundation

enum QueueError: Error {
    case OperationError(String)
}

class Node<T> {
    var value: T
    var next: Node<T>?
    
    init(value: T) {
        self.value = value
    }
}

class Queue<T> {
    var head: Node<T>?
    var tail: Node<T>?
    var count: Int
    
    init() {
        head = nil
        tail = nil
        count = 0
    }
    
    func left() -> Int {
        return self.count
    }
    
    func push(value: T) {
        let node = Node(value: value)
        if head == nil {
            head = node
            tail = head
            return
        } else {
            tail?.next = node
            tail = node
        }
        count += 1
    }
    
    func peek() -> T? {
        if head == nil {
            return nil
        }
        if head?.next == nil {
            return head?.value
        }
        return head?.next?.value
    }
    
    func pop() -> T? {
        if head == nil {
            return nil
        }
        var node = head?.next
        if node != nil {
            head?.next = node?.next
        } else {
            node = head
            head = nil
            tail = nil
        }
        count -= 1
        return node?.value
    }
}

class BlockingQueue<T> {
    let condition = NSCondition()
    
    let queue = Queue<T>()
    
    var isStopped = false
    
    func push(value: T) throws {
        if isStopped {
            throw QueueError.OperationError("push stopped queue")
        }
        
        condition.lock()
        defer { condition.unlock() }
        
        queue.push(value: value)
        condition.signal()
    }
    
    func poll(waitTimeout: Date) -> T? {
        condition.lock()
        defer { condition.unlock() }
        
        if isStopped {
            return queue.pop()
        }
        
        while queue.peek() == nil {
            if !condition.wait(until: waitTimeout) {
                return nil
            }
        }
        return queue.pop()
    }
    
    func poll() -> T? {
        condition.lock()
        defer { condition.unlock() }
        
        if isStopped {
            return queue.pop()
        }
        
        while queue.peek() == nil {
            condition.wait()
        }
        
        return queue.pop()
    }
    
    func peek() -> T? {
        condition.lock()
        defer { condition.unlock() }
        return queue.peek()
    }
    
    func stop() {
        condition.lock()
        defer { condition.unlock() }
        isStopped = true
        condition.signal()
    }
}
