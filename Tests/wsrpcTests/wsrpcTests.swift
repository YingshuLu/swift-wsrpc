import XCTest
@testable import wsrpc

final class wsrpcTests: XCTestCase {
    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(wsrpc().text, "Hello, World!")
    }
}
