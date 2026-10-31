//
//  MakePacketTests.swift
//  netrek-server-swiftTests
//

import XCTest
@testable import netrek_server_swift

// These check the bytes that MakePacket puts on the wire.
final class MakePacketTests: XCTestCase {

    // MARK: - SP_LOGIN

    func testSpLoginIs104BytesWithAZeroKeymap() {
        let data = MakePacket.spLogin(success: true)
        XCTAssertEqual(data.count, 104)
        XCTAssertEqual(data[0], 17)
        XCTAssertEqual(data[1], 1)
        // The keymap is 96 zero bytes starting at offset 8. The last 8 used to
        // be whatever memory followed the struct.
        XCTAssertEqual(Array(data[8 ..< 104]), [UInt8](repeating: 0, count: 96))
    }

    func testSpLoginRejectedIs104BytesWithAZeroKeymap() {
        let data = MakePacket.spLogin(success: false)
        XCTAssertEqual(data.count, 104)
        XCTAssertEqual(data[1], 0)
        XCTAssertEqual(Array(data[8 ..< 104]), [UInt8](repeating: 0, count: 96))
    }

    // MARK: - SP_LASER

    private func laser(target: Int?) -> Laser {
        let laser = Laser()
        laser.laserID = 3
        laser.status = target == nil ? .miss : .hit
        laser.targetPositionX = 5000
        laser.targetPositionY = 7000
        laser.target = target
        return laser
    }

    func testSpLaserWithATargetSendsItInNetworkOrder() {
        let data = MakePacket.spLaser(laser: laser(target: 7))
        XCTAssertEqual(data.count, 16)
        XCTAssertEqual(Array(data[12 ..< 16]), [0, 0, 0, 7])
    }

    func testSpLaserWithoutATargetSends255InNetworkOrder() {
        let data = MakePacket.spLaser(laser: laser(target: nil))
        XCTAssertEqual(data.count, 16)
        XCTAssertEqual(Array(data[12 ..< 16]), [0, 0, 0, 255])
    }

    func testSpLaserPositionsAreInNetworkOrder() {
        let data = MakePacket.spLaser(laser: laser(target: nil))
        // 5000 = 0x1388, 7000 = 0x1B58
        XCTAssertEqual(Array(data[4 ..< 8]), [0, 0, 0x13, 0x88])
        XCTAssertEqual(Array(data[8 ..< 12]), [0, 0, 0x1B, 0x58])
    }
}
