
import XCTest
import os
@testable import wsrpc

final class Endpoint: Service<Chat_Message, Chat_MessageAck> {
    
    private let serviceName = "fusion.exchange.endpoint.chat"
    private let hostId: String
    private let url: String
    
    private let client: Client
    internal var connection: Connection?
    
    init(id: UInt64, url: String) {
        hostId = "\(id)"
        self.url = url
        client = Client(host: hostId)
        super.init(name: serviceName)
        client.addService(service: self, options: Options.withRpcSerializer(type: .protobuf))
    }
    
    func online() -> Bool {
        return connection != nil && !connection!.isClosed
    }
    
    
    func connect() -> Bool {
        do {
            connection = try client.connect(wsUrl: self.url, timeoutSeconds: 3, provider: nil)
            return online()
        } catch let error {
            print("connect \(url) error \(error)")
        }
        return false
    }
    
    override func serve(request: Chat_Message) throws -> Chat_MessageAck {
        print("serve request \(request)")
        var ack = Chat_MessageAck()
        ack.seq = request.seq
        ack.puin = request.puin
        ack.status = 1
        return ack
    }
    
    func send(message: String) -> Bool {
        if !online() {
            return false
        }
        let proxy = connection!.getProxy(name: serviceName, options: Options.withRpcTimeout(timeout: 3), Options.withRpcSerializer(type: .protobuf))
        
        var request = Chat_Message()
        request.seq = 100
        request.puin = 12345
        request.tuin = 12345
        request.content = message
        
        do {
            print("send message \(request)")
            let ack: Chat_MessageAck = try proxy.call(request: request)
            print("receive ack \(ack)")
            return ack.status == 1
        } catch let error {
            print("send message error \(error)")
        }
        return false
    }
    
}

final class LocalTests: XCTestCase {
    func testExample() throws {
        let endpoint = Endpoint(id:12345, url: "ws://localhost:9000/ws/broker")
        XCTAssertTrue(endpoint.connect())
        
        DispatchQueue.global(qos: .userInteractive).async {
            let stream = endpoint.connection?.stream(id: 128, timeout: 10)
            
            guard let listenStream = stream else {
                print(">>>>>>> stream 128 not existed")
                return
            }
            do {
                print(">>>>> stream 128 is listening")
                try listenStream.accept()
                print(">>>>>accept \(listenStream.id()) success")
                
                let content = ">>>>> hello this from stream 128"
                listenStream.write(data: content.data(using: .utf8)!)
                let (code, data) = listenStream.read()
                guard code == .ok else {
                    print(">>>>> read stream error \(code)")
                    return
                }
                print(">>>>> read from stream count: \(data!.count), content: \(String(data: data!, encoding: .utf8))")
                
                sleep(1)
                listenStream.close()
                
            } catch let error {
                print("stream \(listenStream.id()) accept error \(error)")
            }
        }
           
        XCTAssertTrue(endpoint.send(message: "hello this is macos"))
        
        sleep(3)
    }
}
