import XCTest
import NIO
@testable import netrek_server_swift

// Which bind errors let the default `::` fall back to 0.0.0.0.
// main.swift only falls back for the default address, never for --listen-address.
final class ListenAddressTests: XCTestCase {
    func testDefaultsAreUnchanged() {
        XCTAssertEqual(ListenAddress.defaultAddress, "::")
        XCTAssertEqual(ListenAddress.ipv4Fallback, "0.0.0.0")
    }

    func testUnresolvableAddressMeansNoIPv6() {
        // What a Linux host without IPv6 gives for "::" today.
        XCTAssertTrue(ListenAddress.isNoIPv6Error(SocketAddressError.unknown(host: "::", port: 2592)))
    }

    func testKernelWithoutIPv6SocketsMeansNoIPv6() {
        XCTAssertTrue(ListenAddress.isNoIPv6Error(IOError(errnoCode: EAFNOSUPPORT, reason: "socket")))
        XCTAssertTrue(ListenAddress.isNoIPv6Error(IOError(errnoCode: EADDRNOTAVAIL, reason: "bind")))
    }

    func testPortInUseDoesNotFallBack() {
        XCTAssertFalse(ListenAddress.isNoIPv6Error(IOError(errnoCode: EADDRINUSE, reason: "bind")))
        XCTAssertFalse(ListenAddress.isNoIPv6Error(IOError(errnoCode: EACCES, reason: "bind")))
    }

    func testOtherErrorsDoNotFallBack() {
        XCTAssertFalse(ListenAddress.isNoIPv6Error(ChannelError.ioOnClosedChannel))
    }

    // On this machine, binding the default either works, or fails with an error
    // the fallback accepts. Uses port 0 so the system picks a free port.
    func testBindingDefaultAddressWorksOrFallsBack() throws {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        defer { try? group.syncShutdownGracefully() }
        let bootstrap = ServerBootstrap(group: group)
        do {
            let channel = try bootstrap.bind(host: ListenAddress.defaultAddress, port: 0).wait()
            try channel.close().wait()
        } catch {
            XCTAssertTrue(ListenAddress.isNoIPv6Error(error), "binding :: failed with \(error), which would not fall back")
            let channel = try bootstrap.bind(host: ListenAddress.ipv4Fallback, port: 0).wait()
            try channel.close().wait()
        }
    }
}
