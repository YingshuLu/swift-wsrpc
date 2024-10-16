//
//  Options.swift
//  
//
//  Created by yingshulu on 2024/10/16.
//

import Foundation

public typealias Option = (Options) -> Void

public class Options {
    internal var rpcTimeout: UInt64 = 0
    
    internal var roundTripTimeout: UInt64 = 0
    
    internal var serializer: SerializerType = .protobuf
    
    func apply(options: [Option]) {
        for f in options {
            f(self)
        }
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
}
