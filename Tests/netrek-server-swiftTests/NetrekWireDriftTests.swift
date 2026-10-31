//
//  NetrekWireDriftTests.swift
//  netrek-server-swiftTests
//

import XCTest
import NetrekWire
@testable import netrek_server_swift

// This server keeps its own copy of the packet structs and PACKET_SIZES, so
// that it stays close to upstream. NetrekWire (github.com/lismondbernard/NetrekProtocol)
// is the shared reference, and the studio's other code uses it. These tests
// fail if the two copies drift apart. Both modules define the same SP_* names,
// so every type here is written with its module name.
final class NetrekWireDriftTests: XCTestCase {

    private struct Pair {
        let name: String
        let wireSize: Int
        let wireStride: Int
        let wireType: UInt8
        let serverSize: Int
        let serverStride: Int
        /// nil when the server struct cannot be built under test. See `sourceType`.
        let serverType: UInt8?
    }

    /// The first byte of a packet struct is its `type`.
    private func firstByte<T>(_ value: T) -> UInt8 {
        var copy = value
        return withUnsafeBytes(of: &copy) { $0[0] }
    }

    private func pair<W, S>(_ name: String, wire: W, server: S.Type, serverValue: S?) -> Pair {
        return Pair(name: name,
                    wireSize: MemoryLayout<W>.size,
                    wireStride: MemoryLayout<W>.stride,
                    wireType: firstByte(wire),
                    serverSize: MemoryLayout<S>.size,
                    serverStride: MemoryLayout<S>.stride,
                    serverType: serverValue.map { firstByte($0) })
    }

    /// SP_YOU, SP_FLAGS and SP_STATS can only be built from a Player or a User,
    /// and a Universe cannot be created under test (main.swift makes it). For
    /// these the default `type` is read from the declaration in Packets.swift.
    private func sourceType(of structName: String) throws -> UInt8 {
        let path = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/netrek-server-swift/Communication-Network/Packets.swift")
        let source = try String(contentsOf: path, encoding: .utf8)
        let pattern = "struct \(structName) \\{\\s*var type: UInt8 = (\\d+)"
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(source.startIndex..., in: source)
        let match = try XCTUnwrap(regex.firstMatch(in: source, range: range), "no type for \(structName) in Packets.swift")
        let digits = try XCTUnwrap(Range(match.range(at: 1), in: source))
        return try XCTUnwrap(UInt8(source[digits]))
    }

    private var pairs: [Pair] {
        let laser = netrek_server_swift.Laser()
        let planet = netrek_server_swift.Planet(planetID: 0, positionX: 0, positionY: 0, name: "Test", team: .federation)
        return [
            pair("SP_MESSAGE", wire: NetrekWire.SP_MESSAGE(), server: netrek_server_swift.SP_MESSAGE.self,
                 serverValue: netrek_server_swift.SP_MESSAGE(flags: 0, from: 0)),
            pair("SP_PLAYER_INFO", wire: NetrekWire.SP_PLAYER_INFO(), server: netrek_server_swift.SP_PLAYER_INFO.self,
                 serverValue: netrek_server_swift.SP_PLAYER_INFO(playerNum: 0, shipType: 0, team: 0)),
            pair("SP_KILLS", wire: NetrekWire.SP_KILLS(), server: netrek_server_swift.SP_KILLS.self,
                 serverValue: netrek_server_swift.SP_KILLS(playerNum: 0, kills: 0)),
            pair("SP_PLAYER", wire: NetrekWire.SP_PLAYER(), server: netrek_server_swift.SP_PLAYER.self,
                 serverValue: netrek_server_swift.SP_PLAYER(playerNum: 0, directionNetrek: 0, speed: 0, positionX: 0, positionY: 0)),
            pair("SP_TORP_INFO", wire: NetrekWire.SP_TORP_INFO(), server: netrek_server_swift.SP_TORP_INFO.self,
                 serverValue: netrek_server_swift.SP_TORP_INFO(team: .federation, status: .free, number: 0)),
            pair("SP_TORP", wire: NetrekWire.SP_TORP(), server: netrek_server_swift.SP_TORP.self,
                 serverValue: netrek_server_swift.SP_TORP(direction: 0, torpedoNum: 0, positionX: 0, positionY: 0)),
            pair("SP_LASER", wire: NetrekWire.SP_LASER(), server: netrek_server_swift.SP_LASER.self,
                 serverValue: netrek_server_swift.SP_LASER(laser: laser)),
            pair("SP_PLASMA_INFO", wire: NetrekWire.SP_PLASMA_INFO(), server: netrek_server_swift.SP_PLASMA_INFO.self,
                 serverValue: netrek_server_swift.SP_PLASMA_INFO(team: .federation, status: .free, number: 0)),
            pair("SP_PLASMA", wire: NetrekWire.SP_PLASMA(), server: netrek_server_swift.SP_PLASMA.self,
                 serverValue: netrek_server_swift.SP_PLASMA(direction: 0, plasmaNum: 0, positionX: 0, positionY: 0)),
            pair("SP_MOTD", wire: NetrekWire.SP_MOTD(), server: netrek_server_swift.SP_MOTD.self,
                 serverValue: netrek_server_swift.SP_MOTD()),
            pair("SP_YOU", wire: NetrekWire.SP_YOU(), server: netrek_server_swift.SP_YOU.self, serverValue: nil),
            pair("SP_QUEUE", wire: NetrekWire.SP_QUEUE(), server: netrek_server_swift.SP_QUEUE.self,
                 serverValue: netrek_server_swift.SP_QUEUE(position: 0)),
            pair("SP_PLANET", wire: NetrekWire.SP_PLANET(), server: netrek_server_swift.SP_PLANET.self,
                 serverValue: netrek_server_swift.SP_PLANET(planet: planet)),
            pair("SP_PICKOK", wire: NetrekWire.SP_PICKOK(), server: netrek_server_swift.SP_PICKOK.self,
                 serverValue: netrek_server_swift.SP_PICKOK(true)),
            pair("SP_LOGIN", wire: NetrekWire.SP_LOGIN(), server: netrek_server_swift.SP_LOGIN.self,
                 serverValue: netrek_server_swift.SP_LOGIN(success: true)),
            pair("SP_FLAGS", wire: NetrekWire.SP_FLAGS(), server: netrek_server_swift.SP_FLAGS.self, serverValue: nil),
            pair("SP_MASK", wire: NetrekWire.SP_MASK(), server: netrek_server_swift.SP_MASK.self,
                 serverValue: netrek_server_swift.SP_MASK(mask: 0)),
            pair("SP_PLAYER_STATUS", wire: NetrekWire.SP_PLAYER_STATUS(), server: netrek_server_swift.SP_PLAYER_STATUS.self,
                 serverValue: netrek_server_swift.SP_PLAYER_STATUS(playerNum: 0, status: 0)),
            pair("SP_HOSTILE", wire: NetrekWire.SP_HOSTILE(), server: netrek_server_swift.SP_HOSTILE.self,
                 serverValue: netrek_server_swift.SP_HOSTILE(playerID: 0, war: 0, hostile: 0)),
            pair("SP_STATS", wire: NetrekWire.SP_STATS(), server: netrek_server_swift.SP_STATS.self, serverValue: nil),
            pair("SP_PL_LOGIN", wire: NetrekWire.SP_PL_LOGIN(), server: netrek_server_swift.SP_PL_LOGIN.self,
                 serverValue: netrek_server_swift.SP_PL_LOGIN(playerNum: 0, rank: 0)),
            pair("SP_PLANET_LOC", wire: NetrekWire.SP_PLANET_LOC(), server: netrek_server_swift.SP_PLANET_LOC.self,
                 serverValue: netrek_server_swift.SP_PLANET_LOC(planetID: 0, positionX: 0, positionY: 0)),
        ]
    }

    func testEveryServerPacketIsCovered() {
        // 22 SP_* structs in Packets.swift. NetrekWire also has SP_SHIP_CAP,
        // which this server does not send.
        XCTAssertEqual(pairs.count, 22)
        XCTAssertEqual(Set(pairs.map { $0.name }).count, 22)
    }

    func testStructSizeAndStrideMatchNetrekWire() {
        for pair in pairs {
            XCTAssertEqual(pair.serverSize, pair.wireSize, "\(pair.name) size")
            XCTAssertEqual(pair.serverStride, pair.wireStride, "\(pair.name) stride")
        }
    }

    func testTypeBytesMatchNetrekWire() throws {
        for pair in pairs {
            let serverType = try pair.serverType ?? sourceType(of: pair.name)
            XCTAssertEqual(serverType, pair.wireType, "\(pair.name) type byte")
        }
    }

    func testPacketSizesMatchNetrekWire() {
        let server = PACKET_SIZES
        let wire = CLIENT_PACKET_SIZES
        for key in Set(server.keys).union(wire.keys).sorted() {
            XCTAssertEqual(server[key], wire[key], "client packet type \(key)")
        }
        XCTAssertEqual(server, wire)
    }
}
