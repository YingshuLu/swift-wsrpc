//
//  Options.swift
//  
//
//  Created by yingshulu on 2024/10/16.
//

import Foundation

@available(macOS 11.0, *)
public typealias Option = (Options) -> Void

@available(macOS 11.0, *)
public typealias EventHandler = (Connection) -> Void

@available(macOS 11.0, *)
public typealias Events = [EventHandler]

@available(macOS 11.0, *)
internal extension Events {
    static func + (events: Events, event: @escaping EventHandler) -> Events {
        var newEvents = events
        newEvents.append(event)
        return newEvents
    }
    
    func invoke(connection: Connection) {
        for event in self {
            event(connection)
        }
    }
}

@available(macOS 11.0, *)
public class Options {
    internal var rpcTimeout: UInt64 = 0
    
    internal var roundTripTimeout: UInt64 = 0
    
    internal var serializer: SerializerType = .protobuf
    
    internal var onConnectedEvents = Events()
    
    internal var onDisconnectedEvents = Events()
    
    deinit {
        onConnectedEvents.removeAll()
        onDisconnectedEvents.removeAll()
    }
    
    func apply(options: [Option]) {
        for f in options {
            f(self)
        }
    }
    
    public func clone() -> Options {
        let options = Options()
        options.rpcTimeout = self.rpcTimeout
        options.roundTripTimeout = self.roundTripTimeout
        options.serializer = self.serializer
        options.onConnectedEvents = self.onConnectedEvents
        options.onDisconnectedEvents = self.onDisconnectedEvents
        return options
    }
    
    public static func withRpcTimeout(timeout: UInt64) -> Option {
        return { options in
            options.rpcTimeout = timeout
        }
    }
    
    public static func withRpcSerializer(type: SerializerType) -> Option {
        return { options in
            options.serializer = type
        }
    }
    
    public static func withConnectedEvent(event: @escaping EventHandler) -> Option {
        return { options in
            options.onConnectedEvents = options.onConnectedEvents + event
        }
    }
    
    public static func withDisconnectedEvent(event: @escaping EventHandler) -> Option {
        return { options in
            options.onDisconnectedEvents = options.onDisconnectedEvents + event
        }
    }
}
