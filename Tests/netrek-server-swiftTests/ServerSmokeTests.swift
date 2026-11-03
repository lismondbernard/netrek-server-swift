import XCTest
import Foundation
import NIO
import NetrekWire

// End-to-end check of the real server binary: start it, connect over TCP as a
// classic client would, and stop it with SIGTERM.
//
// Valid packets cannot be unit tested yet, because decoding them reaches the
// `universe` global that main.swift creates. This test runs main.swift for real,
// in its own process.
//
// It is skipped unless NETREK_SMOKE_TEST=1, because it starts a server, uses a
// TCP port, and on macOS would advertise over Bonjour. The Linux CI job sets it.
// NETREK_SERVER_BINARY picks the binary to run; the default is the
// netrek-server-swift built next to this test bundle.
//
// The client side is built from NetrekWire, not from the server's own packet
// code, and server packets are framed with NetrekWire's SERVER_PACKET_SIZES.
final class ServerSmokeTests: XCTestCase {
    // Server packet types (classic packets.h).
    private let SP_PLAYER_INFO: UInt8 = 2
    private let SP_KILLS: UInt8 = 3
    private let SP_PLAYER: UInt8 = 4
    private let SP_MOTD: UInt8 = 11
    private let SP_YOU: UInt8 = 12
    private let SP_PLANET: UInt8 = 15
    private let SP_PICKOK: UInt8 = 16
    private let SP_LOGIN: UInt8 = 17
    private let SP_MASK: UInt8 = 19
    private let SP_PSTATUS: UInt8 = 20
    private let SP_PL_LOGIN: UInt8 = 24
    private let SP_PLANET_LOC: UInt8 = 26

    private var group: MultiThreadedEventLoopGroup!
    private var server: Process?
    private var directory: URL!
    private var outputURL: URL!

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["NETREK_SMOKE_TEST"] == "1",
                          "set NETREK_SMOKE_TEST=1 to run the server smoke test")
        group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("netrek-smoke-\(UUID().uuidString)")
        outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("netrek-smoke-\(UUID().uuidString).out")
    }

    override func tearDownWithError() throws {
        if let server = server, server.isRunning {
            server.terminate()
            server.waitUntilExit()
        }
        try? group?.syncShutdownGracefully()
        if let directory = directory { try? FileManager.default.removeItem(at: directory) }
        if let outputURL = outputURL { try? FileManager.default.removeItem(at: outputURL) }
    }

    func testGuestCanLogInOutfitAndQuitAndServerSavesOnSigterm() throws {
        let port = try freePort()
        let process = try startServer(port: port)
        server = process

        // 1. Connect and send CP_SOCKET, as classic clients do first.
        let client = try connect(port: port)
        try client.send(CP_SOCKET(version: 4, udpVersion: 10, port: UInt32(0).bigEndian))
        try waitFor("SP_MOTD and SP_YOU after CP_SOCKET", client) {
            $0.contains(type: self.SP_MOTD) && $0.contains(type: self.SP_YOU)
        }
        let motd = client.packets(type: SP_MOTD).compactMap { motdText($0) }
        XCTAssertFalse(motd.isEmpty)
        let you = try XCTUnwrap(client.packets(type: SP_YOU).last)
        let slot = you[1] // SP_YOU pnum
        XCTAssertLessThan(Int(slot), 100)

        // 2. Log in as a guest.
        var login = CP_LOGIN(query: 0)
        withUnsafeMutableBytes(of: &login.name) { name in
            for (index, byte) in "guest".utf8.enumerated() { name[index] = byte }
        }
        withUnsafeMutableBytes(of: &login.login) { userinfo in
            for (index, byte) in "smoketest".utf8.enumerated() { userinfo[index] = byte }
        }
        try client.send(login)
        try waitFor("SP_LOGIN and the galaxy after CP_LOGIN", client) {
            $0.contains(type: self.SP_LOGIN) && $0.contains(type: self.SP_MASK)
        }
        let spLogin = try XCTUnwrap(client.packets(type: SP_LOGIN).first)
        XCTAssertEqual(spLogin[1], 1, "SP_LOGIN accept")
        // The initial transfer: every planet's location, and the players.
        let planetLocations = client.packets(type: SP_PLANET_LOC)
        XCTAssertEqual(planetLocations.count, 40, "one SP_PLANET_LOC per planet")
        XCTAssertFalse(client.packets(type: SP_PLAYER_INFO).isEmpty)
        XCTAssertFalse(client.packets(type: SP_PL_LOGIN).isEmpty)
        XCTAssertFalse(client.packets(type: SP_PSTATUS).isEmpty)

        // 3. Outfit: Federation, cruiser.
        try client.send(CP_OUTFIT(team: 0, ship: 2))
        try waitFor("SP_PICKOK after CP_OUTFIT", client) { $0.contains(type: self.SP_PICKOK) }
        let pickOk = try XCTUnwrap(client.packets(type: SP_PICKOK).last)
        XCTAssertEqual(pickOk[1], 1, "SP_PICKOK state")
        // Once in the game, the server sends the regular updates.
        try waitFor("SP_PLAYER and SP_PLANET updates after SP_PICKOK", client) {
            $0.contains(type: self.SP_PLAYER) && $0.contains(type: self.SP_PLANET)
        }

        // 4. Quit cleanly. Classic clients send CP_BYE; the server closes the connection.
        try client.send(CP_BYE())
        try waitFor("the server to close the connection after CP_BYE", client) { $0.closed }
        XCTAssertNil(client.unframedType, "server sent a packet type NetrekWire cannot frame")

        // 5. SIGTERM: the server saves the user database and exits 0.
        let database = directory.appendingPathComponent("netrek.database")
        try? FileManager.default.removeItem(at: database)
        process.terminate()
        let deadline = Date().addingTimeInterval(15)
        while process.isRunning && Date() < deadline { usleep(50_000) }
        XCTAssertFalse(process.isRunning, "server still running 15 seconds after SIGTERM\n\(output())")
        guard !process.isRunning else { return }
        XCTAssertEqual(process.terminationReason, .exit, output())
        XCTAssertEqual(process.terminationStatus, 0, output())
        // Only the user database is saved at shutdown. netrek.planets is saved once
        // a minute by the game loop, not on SIGTERM, so it is not checked here.
        let saved = try XCTUnwrap(FileManager.default.contents(atPath: database.path), "netrek.database not saved\n\(output())")
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: saved), "netrek.database is not JSON")
        XCTAssertTrue(output().contains("saving user database"), output())
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("log.info").path))
    }

    // MARK: - Server process

    private func serverBinary() -> URL {
        if let path = ProcessInfo.processInfo.environment["NETREK_SERVER_BINARY"], !path.isEmpty {
            return URL(fileURLWithPath: path)
        }
        #if os(macOS)
        let productsDirectory = Bundle.allBundles.first { $0.bundlePath.hasSuffix(".xctest") }!
            .bundleURL.deletingLastPathComponent()
        #else
        let productsDirectory = Bundle.main.bundleURL
        #endif
        return productsDirectory.appendingPathComponent("netrek-server-swift")
    }

    private func startServer(port: Int) throws -> Process {
        let binary = serverBinary()
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: binary.path), "no server binary at \(binary.path)")
        _ = FileManager.default.createFile(atPath: outputURL.path, contents: nil)
        let output = try FileHandle(forWritingTo: outputURL)
        let process = Process()
        process.executableURL = binary
        // No --listen-address: this is the default start-up a droplet would use.
        process.arguments = ["--directory", directory.path, "--port", String(port)]
        process.standardOutput = output
        process.standardError = output
        var environment = ProcessInfo.processInfo.environment
        environment["SWIFT_BACKTRACE"] = "enable=no"
        process.environment = environment
        try process.run()
        return process
    }

    private func output() -> String {
        guard let data = try? Data(contentsOf: outputURL) else { return "(no server output)" }
        return "server output:\n" + String(decoding: data, as: UTF8.self)
    }

    /// Asks the system for a free port, then lets it go for the server to use.
    private func freePort() throws -> Int {
        let channel = try ServerBootstrap(group: group).bind(host: "127.0.0.1", port: 0).wait()
        let port = channel.localAddress!.port!
        try channel.close().wait()
        return port
    }

    // MARK: - Client

    private func connect(port: Int) throws -> SmokeClient {
        let client = SmokeClient()
        let deadline = Date().addingTimeInterval(20)
        var lastError: Error?
        while Date() < deadline {
            guard server?.isRunning == true else {
                XCTFail("server exited during start-up\n\(output())")
                throw ChannelError.ioOnClosedChannel
            }
            do {
                client.channel = try ClientBootstrap(group: group)
                    .channelInitializer { $0.pipeline.addHandler(client.collector) }
                    .connect(host: "127.0.0.1", port: port).wait()
                return client
            } catch {
                lastError = error
                usleep(100_000)
            }
        }
        XCTFail("could not connect to the server on port \(port): \(String(describing: lastError))\n\(output())")
        throw lastError ?? ChannelError.connectTimeout(.seconds(20))
    }

    private func waitFor(_ what: String, _ client: SmokeClient, timeout: TimeInterval = 10,
                         file: StaticString = #filePath, line: UInt = #line,
                         _ condition: @escaping (SmokeClient.Received) -> Bool) throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if client.check(condition) { return }
            usleep(20_000)
        }
        XCTFail("timed out after \(Int(timeout)) seconds waiting for \(what); got types \(client.typeCounts())\n\(output())",
                file: file, line: line)
        throw ChannelError.ioOnClosedChannel
    }

    private func motdText(_ packet: [UInt8]) -> String? {
        // SP_MOTD: type, 3 pad bytes, then 80 bytes of text.
        let text = packet[4...].prefix { $0 != 0 }
        return String(bytes: text, encoding: .ascii)
    }
}

/// A TCP client that frames what the server sends with NetrekWire's table.
private final class SmokeClient {
    struct Received {
        var packets: [[UInt8]] = []
        var closed = false
        func contains(type: UInt8) -> Bool { packets.contains { $0.first == type } }
    }

    final class Collector: ChannelInboundHandler {
        typealias InboundIn = ByteBuffer
        let lock = NSLock()
        var received = Received()
        var pending: [UInt8] = []
        var unframedType: UInt8?

        func channelRead(context: ChannelHandlerContext, data: NIOAny) {
            var buffer = unwrapInboundIn(data)
            lock.lock(); defer { lock.unlock() }
            pending += buffer.readBytes(length: buffer.readableBytes) ?? []
            while let type = pending.first, unframedType == nil {
                let size = SERVER_PACKET_SIZES.indices.contains(Int(type)) ? SERVER_PACKET_SIZES[Int(type)] : 0
                guard size > 0 else {
                    unframedType = type
                    return
                }
                guard pending.count >= size else { return }
                received.packets.append(Array(pending[0..<size]))
                pending.removeFirst(size)
            }
        }

        func channelInactive(context: ChannelHandlerContext) {
            lock.lock(); received.closed = true; lock.unlock()
            context.fireChannelInactive()
        }
    }

    let collector = Collector()
    var channel: Channel?

    func send<Packet>(_ packet: Packet) throws {
        let channel = try XCTUnwrap(self.channel)
        var buffer = channel.allocator.buffer(capacity: MemoryLayout<Packet>.size)
        _ = withUnsafeBytes(of: packet) { buffer.writeBytes($0) }
        let type = Int(buffer.getInteger(at: 0, as: UInt8.self)!)
        XCTAssertEqual(buffer.readableBytes, CLIENT_PACKET_SIZES[type], "client packet \(type) has the wrong size")
        try channel.writeAndFlush(buffer).wait()
    }

    func check(_ condition: (Received) -> Bool) -> Bool {
        collector.lock.lock(); defer { collector.lock.unlock() }
        return condition(collector.received)
    }

    func packets(type: UInt8) -> [[UInt8]] {
        collector.lock.lock(); defer { collector.lock.unlock() }
        return collector.received.packets.filter { $0.first == type }
    }

    var unframedType: UInt8? {
        collector.lock.lock(); defer { collector.lock.unlock() }
        return collector.unframedType
    }

    func typeCounts() -> [UInt8: Int] {
        collector.lock.lock(); defer { collector.lock.unlock() }
        return collector.received.packets.reduce(into: [:]) { $0[$1[0], default: 0] += 1 }
    }
}
