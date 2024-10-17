//
//  Client.swift
//  
//
//  Created by yingshulu on 2023/8/31.
//

import Foundation
import Starscream
import SwiftProtobuf

public typealias HeaderProvider = () ->[String : String]

private class UrlInfo {
    var peer: String
    var url: String
    var provider: HeaderProvider?
    
    init(peer: String, url: String, provider: HeaderProvider?) {
        self.peer = peer
        self.url = url
        self.provider = provider
    }
}

@available(iOS 14.0, macOS 11.0, *)
public class Client {
    private var timeout = 10

    private var host: String
    
    private var services: ServiceHolder = serviceHolder()
    
    private var lock = NSLock()
    
    private var urls = [String : UrlInfo]()
    
    private var isClosed = false
    
    private let backgroundQueue: DispatchQueue
    
    private let timer: DispatchSourceTimer
    
    public init(host: String, timeout: Int = 10, keepConnected: Bool = false, dispatchQueue: DispatchQueue? = nil) {
        self.host = host
        self.timeout = timeout
        
        if let dsqueue = dispatchQueue {
            self.backgroundQueue = dsqueue
        } else {
            self.backgroundQueue = DispatchQueue(label: "com.bulo.wsrpc", qos: .userInteractive, attributes: .concurrent)
        }
        
        self.timer = DispatchSource.makeTimerSource(queue: self.backgroundQueue)
        
        if keepConnected {
            self.inspection()
        }
    }
    
    public func addService<T:SwiftProtobuf.Message, U:SwiftProtobuf.Message>(service: Service<T, U>, options: Option...) {
        self.services.addService(service: service, options: options)
    }
    
    public func connect(wsUrl: String, timeoutSeconds: Int, provider: HeaderProvider?) throws -> Connection {
        var connectTimeout = timeoutSeconds
        if timeoutSeconds <= 0 {
            connectTimeout = self.timeout
        }

        var request = URLRequest(url: URL(string: wsUrl)!)
        request.timeoutInterval = Double(connectTimeout)
        request.setValue(self.host, forHTTPHeaderField: WebSocketUpgrader.hostIdKey)
        if let headers = provider?() {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        let socket = Starscream.WebSocket(request: request)
        let connection = Connection(host: self.host, socket: socket, services: self.services, backgroundQueue: self.backgroundQueue)
    
        socket.callbackQueue = self.backgroundQueue
        socket.delegate = connection
        socket.connect()
        
        if !connection.waitConnected(timeout: DispatchTime.now() + Double(connectTimeout)) {
            #if DEBUG
            print("websocket connect failure")
            #endif
            throw RpcClientError.ConnectError("connect to \(wsUrl) error \(connection.closeError)")
        }
        self.services.addConnection(connection: connection)
        self.lock.lock()
        defer{ self.lock.unlock() }
        self.urls[connection.peer] = UrlInfo(peer: connection.peer, url: wsUrl, provider: provider)
        return connection
    }
    
    public func close() {
        timer.cancel()
        for (peer, _) in self.urls {
            let conn = self.services.getConnection(peer: peer)
            conn?.close()
        }
        isClosed = true
    }
    
    private func inspection() {
        self.backgroundQueue.async {
            self.timer.schedule(deadline: .now(), repeating: .seconds(180))
            self.timer.setEventHandler {
                    for (peer, url) in self.urls {
                        var conn = self.services.getConnection(peer: peer)
                        if conn == nil || conn!.isClosed {
                            do {
                                conn = try self.connect(wsUrl: url.url, timeoutSeconds: self.timeout, provider: url.provider)
                            } catch {
                                continue
                            }
                        }
                    }
                }
            self.timer.resume()
        }
    }
}
