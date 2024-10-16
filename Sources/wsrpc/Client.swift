//
//  Client.swift
//  
//
//  Created by yingshulu on 2023/8/31.
//

import Foundation
import Starscream
import SwiftProtobuf

enum RpcClientError: Error {
    case ConnectError(String)
}

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
    
    private var timeout: Int

    private var host: String
    
    private var services: ServiceHolder = serviceHolder()
    
    private var lock = NSLock()
    
    private var urls = [String : UrlInfo]()
    
    private var isClosed = false
    
    let backgroundQueue = DispatchQueue(label: "com.bulo.wsrpc", attributes: .concurrent)
    
    var timer: DispatchSourceTimer
    
    public init(host: String) {
        self.host = host
        self.timeout = 3
        timer = DispatchSource.makeTimerSource(queue: self.backgroundQueue)
        //self.inspection()
    }
    
    public func addService<T:SwiftProtobuf.Message, U:SwiftProtobuf.Message>(service: Service<T, U>, options: Option...) {
        self.services.addService(service: service, options: options)
    }
    
    public func connect(wsUrl: String, timeoutSeconds: Int, provider: HeaderProvider?) throws -> Connection {
        if timeoutSeconds > 0 {
            self.timeout = timeoutSeconds
        }

        var request = URLRequest(url: URL(string: wsUrl)!)
        request.timeoutInterval = 10
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
        
        if !connection.waitConnected(timeout: DispatchTime.now() + Double(self.timeout)) {
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
            self.timer.schedule(deadline: .now(), repeating: .seconds(600))
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
