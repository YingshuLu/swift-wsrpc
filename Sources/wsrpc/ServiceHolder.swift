//
//  ServiceHolder.swift
//  
//
//  Created by yingshulu on 2023/8/30.
//

import Foundation

@available(macOS 11.0, *)
protocol ServiceHolder {
    func getService(name: String) -> InternalService?
    func addService(service: InternalService) -> Void
    func addConnection(connection: Connection)
    func getConnection(peer: String) -> Connection?
    func removeConnection(peer: String)
}

@available(macOS 11.0, *)
internal class serviceHolder: ServiceHolder {
    private var services = [String : InternalService]()
    private var connections = [String: Connection]()
    private var lock = NSLock()
    
    func getService(name: String) -> InternalService? {
        return services[name]
    }
    
    func addService(service: InternalService) {
        services[service.name] = service
    }
    
    func addConnection(connection: Connection) {
        lock.lock()
        defer { lock.unlock() }
        connections[connection.peer] = connection
    }
    
    func getConnection(peer: String) -> Connection? {
        lock.lock()
        defer { lock.unlock() }
        return connections[peer]
    }
    
    func removeConnection(peer: String) {
        lock.lock()
        defer { lock.unlock() }
        connections[peer] = nil
    }
}
