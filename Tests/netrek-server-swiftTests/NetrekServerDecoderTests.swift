import XCTest
import NIO
import NIOEmbedded
@testable import netrek_server_swift

// These tests feed bytes to the real NetrekServerDecoder through an
// EmbeddedChannel (no sockets). They only use packets the decoder can handle
// without a Universe, because `universe` is created by main.swift, which does
// not run under test. A complete, valid packet would reach `universe`.
final class NetrekServerDecoderTests: XCTestCase {
    private var channel: EmbeddedChannel!

    override func setUpWithError() throws {
        channel = EmbeddedChannel()
        try channel.pipeline.addHandler(ByteToMessageHandler(NetrekServerDecoder())).wait()
    }

    override func tearDownWithError() throws {
        _ = try? channel.finish()
    }

    private func buffer(_ bytes: [UInt8]) -> ByteBuffer {
        var buffer = channel.allocator.buffer(capacity: bytes.count)
        buffer.writeBytes(bytes)
        return buffer
    }

    func testPacketSizesForKnownClientPackets() {
        XCTAssertEqual(PACKET_SIZES[1], 84) // CP_MESSAGE
        XCTAssertEqual(PACKET_SIZES[2], 4)  // CP_SPEED
        XCTAssertEqual(PACKET_SIZES[8], 52) // CP_LOGIN
    }

    func testPacketSizesForScanPlanetAndFeature() {
        XCTAssertEqual(PACKET_SIZES[34], 4)  // CP_SCAN, packets.h scan_cpacket
        XCTAssertEqual(PACKET_SIZES[38], 12) // CP_PLANET, packets.h planet_cpacket
        XCTAssertEqual(PACKET_SIZES[60], 88) // CP_FEATURE
    }

    func testTruncatedScanWaitsForMoreData() throws {
        // Without an entry for type 34 the decoder threw invalidPacket here.
        XCTAssertNoThrow(try channel.writeInbound(buffer([34, 0, 0])))
        XCTAssertNil(try channel.readInbound(as: ByteBuffer.self))
    }

    func testScanFollowedByAnotherPacketIsFramedAsTwoPackets() {
        // A complete CP_SCAN would reach `universe`, which main.swift creates
        // and which does not exist under test (see the note above). So this
        // walks the buffer with the same table the decoder frames by.
        let bytes: [UInt8] = [34, 5, 0, 0,   2, 9, 0, 0]
        var index = 0
        var lengths: [Int] = []
        while index < bytes.count {
            guard let length = PACKET_SIZES[Int(bytes[index])], length > 0 else {
                XCTFail("lost framing at byte \(index)")
                return
            }
            lengths.append(length)
            index += length
        }
        XCTAssertEqual(lengths, [4, 4])
        XCTAssertEqual(index, bytes.count)
    }

    func testUnknownPacketTypeIsRejected() {
        XCTAssertNil(PACKET_SIZES[255])
        XCTAssertThrowsError(try channel.writeInbound(buffer([255, 0, 0, 0]))) { error in
            XCTAssertEqual(error as? NetrekError, NetrekError.invalidPacket)
        }
    }

    func testNullPacketTypeIsRejected() {
        // Type 0 is listed with size 0, which the decoder treats as invalid.
        XCTAssertThrowsError(try channel.writeInbound(buffer([0, 0, 0, 0]))) { error in
            XCTAssertEqual(error as? NetrekError, NetrekError.invalidPacket)
        }
    }

    func testTruncatedPacketWaitsForMoreData() throws {
        // CP_SPEED is 4 bytes. Send 2, so the decoder must wait and not fail.
        XCTAssertNoThrow(try channel.writeInbound(buffer([2, 5])))
        XCTAssertNil(try channel.readInbound(as: ByteBuffer.self))
    }

    func testEmptyBufferWaitsForMoreData() throws {
        XCTAssertNoThrow(try channel.writeInbound(buffer([])))
        XCTAssertNil(try channel.readInbound(as: ByteBuffer.self))
    }
}
