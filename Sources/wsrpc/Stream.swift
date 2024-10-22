//
//  Stream.swift
//
//
//  Created by yingshulu on 2024/10/17.
//

import Foundation
import os

public enum IOCode: Int {
    case error = -1
    case eof = 0
    case ok = 1
}

enum StreamState: Int {
    case inited
    case openning
    case accepting
    case streaming
    case finWait
    case closeWait
    case closed
}

public protocol Stream {
    func id() -> UInt16
    func open() throws
    func accept() throws
    func read() -> (IOCode, Data?)
    func write(data: Data) -> IOCode
    func close()
}

@available(macOS 11.0, *)
internal class StreamController {
    private var streams = [UInt16: StreamImpl]()
    private let lock = NSLock()
    private let timeout: Int
    private let dispatchQueue: DispatchQueue
    
    internal init(timeout: Int, dispatchQueue: DispatchQueue) {
        self.timeout = timeout
        self.dispatchQueue = dispatchQueue
    }
    
    private func idle() -> UInt16 {
        for id in UInt16(1) ... UInt16(65535) {
            guard streams[id] != nil else {
                return id
            }
        }
        return 0
    }
    
    private func clean(stream: Stream) {
        lock.lock()
        defer { lock.unlock() }
        streams.removeValue(forKey: stream.id())
    }
    
    internal func create(timeout: Int?, sendFrame: @escaping (Frame) -> Bool) -> Stream? {
        lock.lock()
        defer { lock.unlock() }
        
        let id = idle()
        if id == 0 {
            return nil
        }
        
        var tm = self.timeout
        if let t = timeout {
            tm = t
        }
        
        let stream = StreamImpl(id: id, timeout: tm, sendFrame: sendFrame, clean: self.clean, dispatchQueue: self.dispatchQueue)
        streams[id] = stream
        
        return stream
    }
    
    internal func get(id: UInt16) -> StreamImpl? {
        lock.lock()
        defer { lock.unlock() }
        return streams[id]
    }
    
    internal func getOrCreate(id: UInt16, timeout: Int? = nil, sendFrame: @escaping ((Frame) -> Bool)) -> StreamImpl? {
        lock.lock()
        defer { lock.unlock() }
        
        var tm = self.timeout
        if let t = timeout {
            tm = t
        }
        
        guard let stream = streams[id] else {
            let s = StreamImpl(id: id, timeout: tm, sendFrame: sendFrame, clean: self.clean, dispatchQueue: self.dispatchQueue)
            streams[id] = s
            return s
        }
        stream.timeout = tm
        return stream
    }
    
    internal func stop() {
        lock.lock()
        defer { lock.unlock() }
        for (_, stream) in streams {
            stream.close()
        }
    }
}

@available(macOS 11.0, *)
class StreamImpl: Stream {

    private let sid: UInt16
    
    internal var timeout: Int
    
    private let cache = BlockingQueue<Frame>()
    
    private let sendFrame: (Frame) -> Bool
    
    private let clean: (Stream) -> Void
    
    private var index: Int32 = 0
    
    private let logger = Logger(subsystem: "com.bulo.wsrpc", category: "Stream")
    
    private var state = StreamState.inited
    
    private var finFrameCondition = DispatchSemaphore(value: 0)
    
    private let dispatchQueue: DispatchQueue
    
    private var lastFrameIndex: UInt16 = 0
    
    internal init(id: UInt16, timeout: Int, sendFrame: @escaping (Frame) -> Bool, clean: @escaping (Stream) -> Void, dispatchQueue: DispatchQueue) {
        self.sid = id
        self.timeout = timeout
        self.sendFrame = sendFrame
        self.clean = clean
        self.dispatchQueue = dispatchQueue
    }
    
    public func id() -> UInt16 {
        return sid
    }
    
    public func open() throws {
        guard state == .inited else {
            throw StreamError.IllegalState("open not allowed with state \(self.state)")
        }
        
        if !sendFrame(openFrame) {
            throw StreamError.SendError("open send frame failed")
        }
        state = .openning
        
        guard let frame = pollFrame() else {
            throw StreamError.RecvError("open recv failed")
        }
        
        guard let type = frameType(frame: frame) else {
            close()
            throw StreamError.BrokenFrame("open recv not invalid frame")
        }
        
        guard type == .accept else {
            close()
            throw StreamError.BrokenFrame("open recv not accept frame")
        }
        
        state = .streaming
    }
    
    public func accept() throws {
        guard state == .inited else {
            throw StreamError.IllegalState("accept not allowed with state \(self.state)")
        }
        
        state = .accepting
        guard let frame = pollFrame() else {
            throw StreamError.RecvError("accept recv failed")
        }
        
        guard let type = frameType(frame: frame) else {
            close()
            throw StreamError.BrokenFrame("accept recv not invalid frame")
        }
        
        guard type == .open else {
            close()
            throw StreamError.BrokenFrame("accpet recv not open frame")
        }
        
        guard sendFrame(acceptFrame) else {
            close()
            throw StreamError.SendError("accpet send failure")
        }
        state = .streaming
    }
    
    public func read() -> (IOCode, Data?) {
    
    readloop:
        
        switch state {
        case .inited, .openning, .accepting, .closed:
            return (.error, nil)
            
        case .closeWait:
            return (.eof, nil)
            
        case .streaming, .finWait:
            break
        }
        
        if state != .streaming && state != .finWait {
            return (.eof, nil)
        }
        
        var finFrame: Frame?
        
        repeat {
            guard let frame = pollFrame() else {
                return (.error, nil)
            }
            
            guard let type = frameType(frame: frame) else {
                return (.error, nil)
            }
            
            // here state should be .streaming or .finWait
            switch type {
            case .close:
                if state == .streaming {
                    if lastFrameIndex + 1 == frame.index {
                        state = .closeWait
                        return (.eof, nil)
                    }
                    logger.debug("# fin first arrive before bin frame!")
                    finFrame = frame
                    continue
                }
                
            case .accept, .open:
                if state == .streaming {
                    close()
                } else { // .finWait
                    finFrameCondition.signal()
                }
                return (.error, nil)
                
            case .stream:
                lastFrameIndex = frame.index
                if let fin = finFrame {
                    push(frame: fin)
                }
                return (.ok, frame.payload)
            }
        }while(true)
        
        return (.error, nil)
    }
    
    public func write(data: Data) -> IOCode {
        switch state {
        case .inited, .openning, .accepting, .closed:
            return .error
            
        case .finWait:
            return .eof
            
        case .streaming, .closeWait:
            break
        }
        
        if state != .streaming && state != .closeWait {
            return .eof
        }
        
        let frame = binFrame(data: data)
        let succeed = sendFrame(frame)
        if !succeed {
            return .error
        }
        return .ok
    }
    
    public func close() {
        if state == .closed || state == .finWait {
            return
        }
        
        defer {
            logger.debug("stream \(self.sid) closed!")
        }
        dispatchQueue.async {
            defer {
                if self.state != .closed {
                    self.clean(self)
                    self.cache.stop()
                }
                self.state = .closed
            }
            
            repeat {
                switch self.state {
                case .inited:
                    self.state = .closed
                    
                case .closed:
                    return
                    
                case .openning, .accepting, .streaming:
                    var finFrameArrived = false
                    if let frame = self.cache.peek() {
                        if let type = self.frameType(frame: frame) {
                            if type == .close {
                                finFrameArrived = true
                            }
                        }
                    }
                    if self.sendFrame(self.finFrame) {
                        self.state = finFrameArrived ? .closed : .finWait
                    } else {
                        self.state = .closed
                    }
                    
                case .finWait:
                    if self.finFrameCondition.wait(timeout: .now() + .seconds(self.timeout)) == .timedOut {
                        self.logger.warning("close finWait timeout")
                    }
                    self.state = .closed
                    
                case .closeWait:
                    let _ = self.sendFrame(self.finFrame)
                    self.state = .closed
                }
            } while(true)
        }
    }
    
    internal func push(frame: Frame) {
        logger.debug("push stream \(self.sid) frame: \(frame.opcode), index: \(frame.index), payload: \(frame.payload.count)")
        if FrameOpcode(rawValue: frame.opcode) == .close {
            if state == .accepting || state == .openning {
                state = .closeWait
            }
            
            if state == .finWait {
                finFrameCondition.signal()
            }
        }
        
        do {
            try cache.push(value: frame)
        } catch let error {
            logger.error("stream push frame \(frame.opcode) error \(error)")
        }
    }
    
    private func binFrame(data: Data) -> Frame {
        let frame = Frame(payload: data)
        frame.flag |= FrameFlag.bin.rawValue
        frame.opcode = FrameOpcode.stream.rawValue
        frame.group = self.sid
        frame.index = nextIndex()
        return frame
    }
    
    private var openFrame: Frame {
        return controlFrame(opcode: .open)
    }
    
    private var acceptFrame: Frame {
        return controlFrame(opcode: .accept)
    }
    
    private var finFrame: Frame {
        var f = controlFrame(opcode: .close)
        f.index = nextIndex()
        return f
    }
    
    private func frameType(frame: Frame) -> FrameOpcode? {
        if let opcode = FrameOpcode(rawValue: frame.opcode) {
            if opcode == .open && frame.flag & FrameFlag.ack.rawValue != 0 {
                return .accept
            }
            return opcode
        }
        return nil
    }
    
    private func controlFrame(opcode: FrameOpcode) -> Frame {
        let frame = Frame()
        frame.flag |= FrameFlag.bin.rawValue
        if opcode == .accept {
            frame.opcode = FrameOpcode.open.rawValue
            frame.flag |= FrameFlag.ack.rawValue
        } else {
            frame.opcode = opcode.rawValue
        }
        frame.group = self.sid
        return frame
    }
    
    private func nextIndex() -> UInt16 {
        if OSAtomicCompareAndSwap32(65535, 1, &self.index) {
            return 1
        }
        return UInt16(OSAtomicAdd32(1, &self.index))
    }
    
    private func pollFrame() -> Frame? {
        guard let frame = cache.poll(waitTimeout: Date().addingTimeInterval(TimeInterval(self.timeout))) else {
            logger.error("stream \(self.id()) poll error")
            return nil
        }
        return frame
    }

}
