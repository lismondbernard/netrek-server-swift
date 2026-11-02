import XCTest
import NIO
import NIOEmbedded
@testable import netrek_server_swift

// What happens to a connection after the decoder rejects a packet type.
//
// main.swift builds each connection's pipeline as
//     NetrekChannelHandler, then ByteToMessageHandler(NetrekServerDecoder()).
// NetrekChannelHandler needs a Universe, which cannot be made under test, so
// this pipeline puts a recorder in its place (before the decoder) and another
// recorder after the decoder. The recorders only note what reaches them.
//
// These tests pin down today's behaviour. They do not say it is right.
// The classic server (ntserv/socket.c doRead) logs an unknown packet type,
// drops the rest of that read, and keeps the connection open and working.
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
    private var beforeDecoder: ErrorRecorder!
    private var afterDecoder: ErrorRecorder!

    override func setUpWithError() throws {
        channel = EmbeddedChannel()
        beforeDecoder = ErrorRecorder()
        afterDecoder = ErrorRecorder()
        try channel.pipeline.addHandler(beforeDecoder).wait()
        try channel.pipeline.addHandler(ByteToMessageHandler(NetrekServerDecoder())).wait()
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

    /// Sends a bad packet type and returns the error EmbeddedChannel rethrows.
    private func sendBadPacketType() -> Error? {
        var thrown: Error?
        XCTAssertThrowsError(try channel.writeInbound(buffer([255, 0, 0, 0]))) { thrown = $0 }
        return thrown
    }

    func testDecoderErrorDoesNotReachTheHandlerBeforeIt() {
        let thrown = sendBadPacketType()
        XCTAssertEqual(thrown as? NetrekError, .invalidPacket)

        // NetrekChannelHandler.errorCaught sits where beforeDecoder is, so it
        // never runs and never closes the connection or frees the player slot.
        XCTAssertTrue(beforeDecoder.errors.isEmpty)
        XCTAssertEqual(afterDecoder.errors.count, 1)
        XCTAssertEqual(afterDecoder.errors.first as? NetrekError, .invalidPacket)
    }

    func testConnectionStaysOpenAfterBadPacketType() {
        _ = sendBadPacketType()
        XCTAssertTrue(channel.isActive)
    }

    func testLaterBytesAreRejectedWithoutBeingDecoded() {
        _ = sendBadPacketType()

        // One byte of a CP_SPEED. A healthy decoder would wait for the other three.
        // After the error, ByteToMessageHandler refuses all further data, so the
        // connection is open but dead: nothing the client sends is decoded again.
        XCTAssertThrowsError(try channel.writeInbound(buffer([2]))) { error in
            guard case ByteToMessageDecoderError.dataReceivedInErrorState(let earlier, let refused)? = error as? ByteToMessageDecoderError else {
                return XCTFail("expected dataReceivedInErrorState, got \(error)")
            }
            XCTAssertEqual(earlier as? NetrekError, .invalidPacket)
            XCTAssertEqual(refused.readableBytesView.map { $0 }, [2])
        }
        XCTAssertTrue(channel.isActive)
        XCTAssertTrue(beforeDecoder.errors.isEmpty)
    }
}
