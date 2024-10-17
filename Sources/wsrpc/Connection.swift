//
//  Connection.swift
//  
//
//  Created by yingshulu on 2023/8/30.
//

import Foundation
import Starscream
import os

class ReplyMessageNotify {
    private var semaphore = DispatchSemaphore(value: 0)
    private var sendMessage: (Message) -> Void
    private var message: Message? = nil
    
    init(sendMessage: @escaping (Message) -> Void) {
        self.sendMessage = sendMessage
    }
    
    func notify(reply: Message) {
        self.message = reply
        semaphore.signal()
    }
    
    func sendAndWait(request: Message, timeout: DispatchTime) -> Message {
        self.sendMessage(request)
        let result = semaphore.wait(timeout: timeout)
        if result == DispatchTimeoutResult.timedOut {
            let timeoutMessage = Message.replyError(id: request.id, error: "call service \(request.service) timeout")
            return timeoutMessage
        }
        return self.message!
    }
}

class WebSocketUpgrader {
    static let connectionIdKey = "X-CONNECTION-ID"
    static let hostIdKey = "X-HOST-ID"
    static let authTokenKey = "X-AUTH-TOKEN"
}

@available(iOS 14.0, macOS 11.0, *)
public class Connection: WebSocketDelegate {

    private var connectedSemaphore = DispatchSemaphore(value: 0) 

    public var host: String
    
    public var id: String = "anoymous"
    
    public var peer: String = "anonymous"
    
    public var isClosed: Bool = false
    
    var closeError: String = ""
    
    private var services: ServiceHolder
    
    private var messageId: Int32 = 0
    
    private let waitTimeout = Date(timeIntervalSinceNow: 60)
    
    private var replyNotifyLock = NSLock()
    
    private var replyNotifyMap = [UInt32:ReplyMessageNotify]()
    
    private var socket: Starscream.WebSocket
    
    private let sendingQueue = BlockingQueue<Frame>()
    
    private var cacheData = Connection.EmptyData
    
    private let backgroundQueue: DispatchQueue
    
    private var logger = Logger(subsystem: "com.bulo.wsrpc", category: "Connection")
    
    static private let EmptyData = Data()
    
    init(host: String, socket: Starscream.WebSocket, services: ServiceHolder, backgroundQueue: DispatchQueue) {
        self.host = host
        self.socket = socket
        self.services = services
        self.backgroundQueue = backgroundQueue
    }
    
    public func close() {
        if !isClosed {
            services.removeConnection(peer: self.peer)
            isClosed = true
            sendingQueue.stop()
            socket.disconnect()
            
            // break circle reference
            socket.delegate = nil
        }
    }
    
    public func didReceive(event: WebSocketEvent, client: WebSocketClient) {
        switch event {
        case .connected(let headers):
            self.id = getHttpFieldValue(headers, WebSocketUpgrader.connectionIdKey) ?? "anoymous"
            self.peer = getHttpFieldValue(headers, WebSocketUpgrader.hostIdKey) ?? "anonymous"
            writePumpThread()
            connectedSemaphore.signal()
            
        case .disconnected:
            self.close()
            
        case .binary(let data):
            handleFrame(data: data)
            
        case .peerClosed:
            self.close()
            
        case .error(let closeError):
            self.close()
            self.closeError = closeError?.localizedDescription ?? "close with error"
            
        case .text, .pong, .ping:
            break
            
        case .viabilityChanged, .reconnectSuggested, .cancelled:
            break
        }
    }
    
    private func getHttpFieldValue(_ headers: [String:String], _ field: String) -> String? {
        for (key, value) in headers {
            if key.uppercased() == field {
                return value
            }
        }
        return nil
    }
    
    private func nextMessageId() -> UInt32 {
        return UInt32(OSAtomicAdd32(1, &self.messageId))
    }
    
    internal func call(name: String, requestData: Data, options: Options) throws -> Message {
        let requestMessage = Message(data: requestData)
        requestMessage.type = RpcType.request.rawValue
        requestMessage.id = self.nextMessageId()
        requestMessage.service = name
        
        let notify = ReplyMessageNotify(sendMessage: self.sendMessage)
        setReplyNotify(id: requestMessage.id, notify: notify)
        defer { removeReplyNotify(id: requestMessage.id) }
        
        return notify.sendAndWait(request: requestMessage,
                                              timeout: DispatchTime.now() + Double(options.rpcTimeout))
    }
    
    internal func handleFrame(data: Data) {
        if cacheData.isEmpty {
            cacheData = data
        } else {
            cacheData.append(data)
        }
        
        let (code, frame) = Frame.parse(data: cacheData)
        switch code {
        case .ok:
            guard let rpcFrame = frame else {
                logger.error("parse frame ok, but frame is null, Bug!")
                close()
                return
            }
            
            if rpcFrame.count == cacheData.count {
                cacheData = Connection.EmptyData
            } else {
                cacheData = cacheData.subdata(in: cacheData.startIndex + rpcFrame.count ..< cacheData.endIndex)
            }
            handleRpc(frame: rpcFrame)
            
        case .needMore:
            break
            
        case .illegal:
            logger.error("parse frame error, closing...")
            close()
        }
    }
    
    internal func handleRpc(frame: Frame) {
        let (code, anyMesssage) = Message.decode(data: frame.payload)
        if code != RpcParseCode.ok {
            logger.error("wsrpc decode message error")
            return
        }
        
        guard let message = anyMesssage else {
            return
        }
        
        switch RpcType(rawValue: message.type) {
        case .request:
            backgroundQueue.async {
                let name = message.service
                if let service = self.services.getService(name: name) {
                    let replyMessage = service.invokeInternal(requestMessage: message)
                    self.sendMessage(message: replyMessage)
                } else {
                    self.sendMessage(message: self.replyServiceNotFound(request: message))
                }
            }
            break
            
        case .reply, .error:
            let notify = getReplyNotify(id: message.id)
            notify?.notify(reply: message)
            
        default:
            break
        }
    }
    
    internal func getReplyNotify(id: UInt32) -> ReplyMessageNotify? {
        replyNotifyLock.lock()
        let notify = replyNotifyMap[id]
        replyNotifyLock.unlock()
        return notify
    }
    
    internal func setReplyNotify(id: UInt32, notify: ReplyMessageNotify) {
        replyNotifyLock.lock()
        replyNotifyMap[id] = notify
        replyNotifyLock.unlock()
    }
    
    internal func removeReplyNotify(id: UInt32) {
        replyNotifyLock.lock()
        replyNotifyMap[id] = nil
        replyNotifyLock.unlock()
    }
    
    private func replyServiceNotFound(request: Message) -> Message {
        return Message.replyError(id: request.id, error: "not found service \(request.service)")
    }
    
    private func sendMessage(message: Message) {
        let data = message.encode()
        let frame = Frame(payload: data)
        frame.flag = FrameFlag.RpcFlag.rawValue
        sendingQueue.push(value: frame)
    }
    
    private func writePumpThread() {
        backgroundQueue.async {
            while !self.isClosed {
                let frame = self.sendingQueue.poll()
                if frame != nil {
                    let data = frame?.toBytes()
                    self.socket.write(data: Data(data!))
                }
            }
        }
    }
    
    internal func waitConnected(timeout: DispatchTime) -> Bool {
        let result = connectedSemaphore.wait(timeout: timeout)
        if result == DispatchTimeoutResult.timedOut {
            close()
            return false
        }
        return !isClosed
    }
    
}
