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
    private var head: Node<T>?
    private var tail: Node<T>?
    private(set) var count: Int = 0
    
    var isEmpty: Bool {
        return head == nil
    }
    
    internal var firstNode: Node<T>? {
        return head
    }
    
    func push(_ value: T) {
        let newNode = Node(value: value)
        if let tailNode = tail {
            tailNode.next = newNode
        } else {
            head = newNode
        }
        tail = newNode
        count += 1
    }
    
    func pop() -> T? {
        if let headNode = head {
            head = headNode.next
            if head == nil {
                tail = nil
            }
            count -= 1
            return headNode.value
        }
        return nil
    }
    
    func peek() -> T? {
        return head?.value
    }
}

class BlockingQueue<T> {
    private let condition = NSCondition()
    private let queue = Queue<T>()
    private(set) var isStopped = false
    
    func push(value: T) throws {
        if isStopped {
            throw QueueError.OperationError("push stopped queue")
        }
        
        condition.lock()
        defer { condition.unlock() }
        
        queue.push(value)
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
