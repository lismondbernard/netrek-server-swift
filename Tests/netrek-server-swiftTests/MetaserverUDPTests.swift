import XCTest
import NIO
@testable import netrek_server_swift

// The metaserver report goes to a UDP listener on 127.0.0.1 here, never to a
// real metaserver.
final class MetaserverUDPTests: XCTestCase {
    private var group: MultiThreadedEventLoopGroup!
    private var listener: UDPListener!

    override func setUpWithError() throws {
        group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        listener = try UDPListener(group: group)
    }

    override func tearDownWithError() throws {
        try listener?.close()
        try group?.syncShutdownGracefully()
    }

    /// Sends and waits until the packets are handed to the socket.
    private func send(_ report: String, with metaserver: MetaserverUDP) -> [SocketAddress] {
        let done = expectation(description: "sent")
        var sentTo: [SocketAddress] = []
        metaserver.send(report: report) { addresses in
            sentTo = addresses
            done.fulfill()
        }
        wait(for: [done], timeout: 10)
        return sentTo
    }

    func testReportArrivesAsSentAtALocalListener() throws {
        let metaserver = try XCTUnwrap(MetaserverUDP(hosts: [MetaserverHost(name: "127.0.0.1", port: listener.port)], group: group))
        let report = "b\nnetrek.example.org\nE\n2592\n0\n0\n16\nn\nn\nn\nSwift-IPv6-empire\n"
        _ = send(report, with: metaserver)
        let packets = listener.waitForPackets(count: 1)
        XCTAssertEqual(packets, [Array(report.utf8)])
    }

    func testHostNamesAreLookedUpAtSendTime() throws {
        // "localhost" goes through getaddrinfo, the same lookup the real names use.
        var lookups: [String] = []
        let lock = NSLock()
        let metaserver = try XCTUnwrap(MetaserverUDP(hosts: [MetaserverHost(name: "localhost", port: listener.port)], group: group) { host in
            lock.lock(); lookups.append(host.name); lock.unlock()
            return MetaserverUDP.resolveIPv4(host)
        })
        lock.lock(); XCTAssertEqual(lookups, [], "looked up before any report was sent"); lock.unlock()
        let sentTo = send("first", with: metaserver)
        XCTAssertEqual(sentTo.map(\.ipAddress), ["127.0.0.1"])
        _ = send("second", with: metaserver)
        lock.lock(); XCTAssertEqual(lookups, ["localhost", "localhost"], "one lookup per report"); lock.unlock()
        XCTAssertEqual(listener.waitForPackets(count: 2).map { String(decoding: $0, as: UTF8.self) }, ["first", "second"])
    }

    func testTwoNamesForOneAddressGetOnePacket() throws {
        // metaserver.us.netrek.org and metaserver2.us.netrek.org are the same
        // address today. Two packets at once would get the server delisted for flooding.
        let hosts = [MetaserverHost(name: "localhost", port: listener.port),
                     MetaserverHost(name: "127.0.0.1", port: listener.port)]
        let metaserver = try XCTUnwrap(MetaserverUDP(hosts: hosts, group: group))
        let sentTo = send("once", with: metaserver)
        XCTAssertEqual(sentTo.count, 1)
        XCTAssertEqual(listener.waitForPackets(count: 1).count, 1)
        // Give a second packet time to arrive, if one was sent.
        usleep(200_000)
        XCTAssertEqual(listener.packets.count, 1)
    }

    func testANameThatDoesNotResolveIsSkipped() throws {
        let hosts = [MetaserverHost(name: "gone.example"),
                     MetaserverHost(name: "127.0.0.1", port: listener.port)]
        let metaserver = try XCTUnwrap(MetaserverUDP(hosts: hosts, group: group) { host in
            host.name == "gone.example" ? nil : MetaserverUDP.resolveIPv4(host)
        })
        let sentTo = send("still sent", with: metaserver)
        XCTAssertEqual(sentTo.map(\.ipAddress), ["127.0.0.1"])
        XCTAssertEqual(listener.waitForPackets(count: 1).map { String(decoding: $0, as: UTF8.self) }, ["still sent"])
    }

    func testSendDoesNotWaitForTheLookup() throws {
        let lookupMayFinish = DispatchSemaphore(value: 0)
        let metaserver = try XCTUnwrap(MetaserverUDP(hosts: [MetaserverHost(name: "127.0.0.1", port: listener.port)], group: group) { host in
            lookupMayFinish.wait() // a slow DNS server
            return MetaserverUDP.resolveIPv4(host)
        })
        let done = expectation(description: "sent")
        let start = Date()
        metaserver.send(report: "slow") { _ in done.fulfill() }
        XCTAssertLessThan(Date().timeIntervalSince(start), 0.5, "send waited for the lookup")
        lookupMayFinish.signal()
        wait(for: [done], timeout: 10)
        XCTAssertEqual(listener.waitForPackets(count: 1).count, 1)
    }

    func testResolveIPv4GivesAnIPv4Address() {
        let address = MetaserverUDP.resolveIPv4(MetaserverHost(name: "localhost", port: 3521))
        XCTAssertEqual(address?.protocol, .inet)
        XCTAssertEqual(address?.port, 3521)
        XCTAssertEqual(address?.ipAddress, "127.0.0.1")
    }

    func testMetaserverArguments() {
        XCTAssertEqual(MetaserverHost(argument: "metaserver.us.netrek.org"), MetaserverHost(name: "metaserver.us.netrek.org", port: 3521))
        XCTAssertEqual(MetaserverHost(argument: "127.0.0.1:4000"), MetaserverHost(name: "127.0.0.1", port: 4000))
        XCTAssertNil(MetaserverHost(argument: ""))
        XCTAssertNil(MetaserverHost(argument: "host:"))
        XCTAssertNil(MetaserverHost(argument: ":3521"))
        XCTAssertNil(MetaserverHost(argument: "host:0"))
        XCTAssertNil(MetaserverHost(argument: "host:70000"))
        XCTAssertNil(MetaserverHost(argument: "host:port"))
        XCTAssertNil(MetaserverHost(argument: "::1"))
    }

    func testDefaultMetaserversAreVanillas() {
        // quozl/netrek-server docs/sample_metaservers:23-25
        XCTAssertEqual(MetaserverHost.defaultNames,
                       ["metaserver.us.netrek.org", "metaserver2.us.netrek.org", "metaserver3.us.netrek.org"])
        XCTAssertEqual(MetaserverHost.defaultPort, 3521)
    }
}

/// Collects the UDP packets sent to it on 127.0.0.1.
final class UDPListener {
    private final class Collector: ChannelInboundHandler {
        typealias InboundIn = AddressedEnvelope<ByteBuffer>
        let lock = NSLock()
        var packets: [[UInt8]] = []
        func channelRead(context: ChannelHandlerContext, data: NIOAny) {
            var envelope = unwrapInboundIn(data)
            let bytes = envelope.data.readBytes(length: envelope.data.readableBytes) ?? []
            lock.lock(); packets.append(bytes); lock.unlock()
        }
    }

    private let collector = Collector()
    private let channel: Channel
    let port: Int

    init(group: EventLoopGroup) throws {
        let collector = self.collector
        channel = try DatagramBootstrap(group: group)
            .channelInitializer { $0.pipeline.addHandler(collector) }
            .bind(host: "127.0.0.1", port: 0).wait()
        port = channel.localAddress!.port!
    }

    var packets: [[UInt8]] {
        collector.lock.lock(); defer { collector.lock.unlock() }
        return collector.packets
    }

    func waitForPackets(count: Int, timeout: TimeInterval = 10) -> [[UInt8]] {
        let deadline = Date().addingTimeInterval(timeout)
        while packets.count < count && Date() < deadline { usleep(10_000) }
        return packets
    }

    func close() throws {
        try channel.close().wait()
    }
}
