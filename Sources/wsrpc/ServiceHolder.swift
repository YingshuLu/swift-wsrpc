//
//  ServiceHolder.swift
//  
//
//  Created by yingshulu on 2023/8/30.
//

import Foundation

@available(macOS 11.0, *)
protocol ServiceHolder {
    func GetService(name: String) -> InternalService?
    func AddService(service: InternalService) -> Void
    func AddConnection(connection: Connection)
    func GetConnection(peer: String) -> Connection?
    func RemoveConnection(peer: String)
}

@available(macOS 11.0, *)
internal class serviceHolder: ServiceHolder {
    private var services = [String : InternalService]()
    private var connections = [String: Connection]()
    private var lock = NSLock()
    
    func GetService(name: String) -> InternalService? {
        return services[name]
    }
    
    func AddService(service: InternalService) {
        services[service.name] = service
    }
    
    func AddConnection(connection: Connection) {
        lock.lock()
        defer { lock.unlock() }
        connections[connection.peer] = connection
    }
    
    func GetConnection(peer: String) -> Connection? {
        lock.lock()
        defer { lock.unlock() }
        return connections[peer]
    }
    
    func RemoveConnection(peer: String) {
        lock.lock()
        defer { lock.unlock() }
        connections[peer] = nil
    }
}
