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
    
    let backgroundQueue: DispatchQueue
    
    private var logger = Logger(subsystem: "com.bulo.wsrpc", category: "Connection")
    
    init(host: String, socket: Starscream.WebSocket, services: ServiceHolder, backgroundQueue: DispatchQueue) {
        self.host = host
        self.socket = socket
        self.services = services
        self.backgroundQueue = backgroundQueue
    }
    
    public func didReceive(event: WebSocketEvent, client: WebSocketClient) {
        switch event {
        case .connected(let headers):
            self.id = getHttpFieldValue(headers, WebSocketUpgrader.connectionIdKey) ?? "anoymous"
            self.peer = getHttpFieldValue(headers, WebSocketUpgrader.hostIdKey) ?? "anonymous"
            writePumpThread()
            
        case .disconnected:
            self.close()
            
        case .binary(let data):
            var bytes = [UInt8](data)
            let (code, frame) = Frame.Parse(data: &bytes)
            if code != ParseCode.ok {
                logger.error("parse frame error")
                break
            }
            handleRpc(frame: frame!)

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
    
    func getHttpFieldValue(_ headers: [String:String], _ field: String) -> String? {
        for (key, value) in headers {
            if key.uppercased() == field {
                return value
            }
        }
        return nil
    }
    
    func nextMessageId() -> UInt32 {
        return UInt32(OSAtomicAdd32(1, &self.messageId))
    }
    
    func call(name: String, requestData: [UInt8], options: Options) throws -> Message {
        let requestMessage = Message(data: requestData)
        requestMessage.type = RpcType.request.rawValue
        requestMessage.id = self.nextMessageId()
        requestMessage.service = name
        
        let notify = ReplyMessageNotify(sendMessage: self.sendMessage)
        setReplyNotify(id: requestMessage.id, notify: notify)
        defer { removeReplyNotify(id: requestMessage.id) }
        
        return notify.sendAndWait(request: requestMessage,
                                              timeout: DispatchTime.now() + Double(options.RpcTimeout))
    }
    
    func handleRpc(frame: Frame) {
        var payload = frame.payload
        let (code, anyMesssage) = Message.Decode(data: &payload!)
        if code != RpcParseCode.ok {
            return
        }
        
        let message: Message = anyMesssage!
        switch message.type {
        case RpcType.request.rawValue:
            let name = message.service
            let service = self.services.GetService(name: name)
            if service != nil {
                let replyMessage = service!.invokeInternal(requestMessage: message)
                self.sendMessage(message: replyMessage)
            } else {
                self.sendMessage(message: replyServiceNotFound(request: message))
            }
            break
            
        case RpcType.reply.rawValue, RpcType.error.rawValue:
            let notify = getReplyNotify(id: message.id)
            notify?.notify(reply: message)
            
        default:
            break
        }
        
    }
    
    func getReplyNotify(id: UInt32) -> ReplyMessageNotify? {
        replyNotifyLock.lock()
        let notify = replyNotifyMap[id]
        replyNotifyLock.unlock()
        return notify
    }
    
    func setReplyNotify(id: UInt32, notify: ReplyMessageNotify) {
        replyNotifyLock.lock()
        replyNotifyMap[id] = notify
        replyNotifyLock.unlock()
    }
    
    func removeReplyNotify(id: UInt32) {
        replyNotifyLock.lock()
        replyNotifyMap[id] = nil
        replyNotifyLock.unlock()
    }
    
    func replyServiceNotFound(request: Message) -> Message {
        return Message.replyError(id: request.id, error: "not found service \(request.service)")
    }
    
    func sendMessage(message: Message) {
        let data = message.Encode()
        let frame = Frame(payload: data)
        frame.flag = FrameFlag.RpcFlag.rawValue
        sendingQueue.push(value: frame)
    }
    
    func writePumpThread() {
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
    
    func close() {
        if !isClosed {
            services.RemoveConnection(peer: self.peer)
            isClosed = true
            sendingQueue.stop()
            socket.disconnect()
            
            // break circle reference
            socket.delegate = nil
        }
    }
    
}
