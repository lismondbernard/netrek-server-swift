import XCTest
import NIO
import NIOEmbedded
@testable import netrek_server_swift

// What happens to a connection after the client sends an unknown packet type.
//
// main.swift builds each connection's pipeline as
//     NetrekChannelHandler, then ByteToMessageHandler(NetrekServerDecoder()).
// NetrekChannelHandler needs a Universe, which cannot be made under test, so
// this pipeline puts a recorder in its place (before the decoder) and another
// recorder after the decoder. The recorders only note what reaches them.
//
// The server does what the classic server does (ntserv/socket.c doRead,
// lines 1006-1011 at quozl/netrek-server 43b641f): log the unknown type, drop
// the rest of what was read, and keep the connection open and working.
//
// The good packet these tests send is CP_FEATURE, because decoding it does not
// reach `universe`, which main.swift creates and which does not exist under test.
final class BadPacketConnectionTests: XCTestCase {
    private final class ErrorRecorder: ChannelInboundHandler {
        typealias InboundIn = ByteBuffer
        var errors: [Error] = []
        func errorCaught(context: ChannelHandlerContext, error: Error) {
            errors.append(error)
            context.fireErrorCaught(error)
        }
    }

    private var channel: EmbeddedChannel!
    private var decoder: NetrekServerDecoder!
    private var beforeDecoder: ErrorRecorder!
    private var afterDecoder: ErrorRecorder!

    override func setUpWithError() throws {
        channel = EmbeddedChannel()
        decoder = NetrekServerDecoder()
        beforeDecoder = ErrorRecorder()
        afterDecoder = ErrorRecorder()
        try channel.pipeline.addHandler(beforeDecoder).wait()
        // NetrekServerDecoder is a class, so `decoder` is the one the handler uses.
        try channel.pipeline.addHandler(ByteToMessageHandler(decoder)).wait()
        try channel.pipeline.addHandler(afterDecoder).wait()
        // EmbeddedChannel starts inactive; connect it so it looks like an accepted client.
        try channel.connect(to: SocketAddress(ipAddress: "127.0.0.1", port: 2592)).wait()
    }

    override func tearDownWithError() throws {
        _ = try? channel.finish()
    }

    private func buffer(_ bytes: [UInt8]) -> ByteBuffer {
        var buffer = channel.allocator.buffer(capacity: bytes.count)
        buffer.writeBytes(bytes)
        return buffer
    }

    private let badPacket: [UInt8] = [255, 0, 0, 0]

    /// A whole CP_FEATURE (type 60, 88 bytes).
    private var feature: [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 88)
        bytes[0] = 60
        XCTAssertEqual(PACKET_SIZES[60], bytes.count)
        return bytes
    }

    func testBadPacketTypeIsNotAnError() {
        XCTAssertNoThrow(try channel.writeInbound(buffer(badPacket)))
        XCTAssertTrue(beforeDecoder.errors.isEmpty)
        XCTAssertTrue(afterDecoder.errors.isEmpty)
        XCTAssertEqual(decoder.decodedPacketCount, 0)
    }

    func testConnectionStaysOpenAfterBadPacketType() {
        XCTAssertNoThrow(try channel.writeInbound(buffer(badPacket)))
        XCTAssertTrue(channel.isActive)
    }

    func testGoodPacketInALaterWriteIsDecoded() {
        XCTAssertNoThrow(try channel.writeInbound(buffer(badPacket)))
        XCTAssertNoThrow(try channel.writeInbound(buffer(feature)))
        XCTAssertEqual(decoder.decodedPacketCount, 1)
        XCTAssertTrue(channel.isActive)
        XCTAssertTrue(afterDecoder.errors.isEmpty)
    }

    func testBytesAfterTheBadPacketInTheSameWriteAreDropped() {
        // Classic drops the rest of the read, good packets included.
        XCTAssertNoThrow(try channel.writeInbound(buffer(badPacket + feature)))
        XCTAssertEqual(decoder.decodedPacketCount, 0)

        // Nothing was kept: the next CP_FEATURE is framed from its first byte.
        XCTAssertNoThrow(try channel.writeInbound(buffer(feature)))
        XCTAssertEqual(decoder.decodedPacketCount, 1)
        XCTAssertTrue(channel.isActive)
    }

    func testEveryKindOfUnknownTypeIsDropped() {
        // 0 is in the table with size 0; 39 is a gap in the table; 61 and 255 are past its end.
        for (index, type) in [UInt8(0), 39, 61, 255].enumerated() {
            XCTAssertNil(PACKET_SIZES[Int(type)].flatMap { $0 > 0 ? $0 : nil }, "type \(type)")
            XCTAssertNoThrow(try channel.writeInbound(buffer([type, 0, 0, 0])), "type \(type)")
            XCTAssertNoThrow(try channel.writeInbound(buffer(feature)), "type \(type)")
            XCTAssertEqual(decoder.decodedPacketCount, index + 1, "type \(type)")
        }
        XCTAssertTrue(channel.isActive)
        XCTAssertTrue(afterDecoder.errors.isEmpty)
    }

    func testFloodOfBadBytesIsNotKept() throws {
        // Called directly, the decoder empties the buffer it was given.
        let context = try channel.pipeline.syncOperations.context(handlerType: ByteToMessageHandler<NetrekServerDecoder>.self)
        var flood = buffer([UInt8](repeating: 255, count: 64 * 1024))
        XCTAssertEqual(try decoder.decode(context: context, buffer: &flood), .needMoreData)
        XCTAssertEqual(flood.readableBytes, 0)

        // Through the channel: many reads of bad bytes, then a CP_FEATURE split over
        // two reads. If any bad byte had been kept, the CP_FEATURE would be misframed.
        for _ in 0..<1000 {
            XCTAssertNoThrow(try channel.writeInbound(buffer([UInt8](repeating: 255, count: 1024))))
        }
        let packet = feature
        XCTAssertNoThrow(try channel.writeInbound(buffer(Array(packet[0..<40]))))
        XCTAssertEqual(decoder.decodedPacketCount, 0)
        XCTAssertNoThrow(try channel.writeInbound(buffer(Array(packet[40...]))))
        XCTAssertEqual(decoder.decodedPacketCount, 1)
        XCTAssertTrue(channel.isActive)
    }
}
