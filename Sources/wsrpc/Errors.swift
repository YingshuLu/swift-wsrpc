//
//  Errors.swift
//
//
//  Created by yingshulu on 2024/10/16.
//

public enum RpcProxyError: Error {
    case ServiceError(String)
    case SerializeError(String)
}

public enum RpcClientError: Error {
    case ConnectError(String)
}

public enum StreamError: Error {
    case RecvError(String)
    case SendError(String)
    case TimeoutError(String)
    case BrokenFrame(String)
    case IllegalState(String)
}
