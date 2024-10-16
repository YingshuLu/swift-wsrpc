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
