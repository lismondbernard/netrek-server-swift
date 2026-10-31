//
//  ServerPacketLayoutTests.swift
//  netrek-server-swiftTests
//

import XCTest
@testable import netrek_server_swift

/// The senders in MakePacket copy each SP_* struct straight out of memory, so
/// a struct's in-memory size has to equal its classic wire size. These tests
/// pin the sizes and field offsets to classic packets.h. The numbers match
/// NetrekWire's ServerPacketLayoutTests.
final class ServerPacketLayoutTests: XCTestCase {

    func offset<T>(_ key: PartialKeyPath<T>) -> Int? {
        return MemoryLayout<T>.offset(of: key)
    }

    /// An all-zero value of a plain-bytes struct. Several SP_* structs can only
    /// be built from a Player or User, and a Universe cannot be created under
    /// test, so the declared `size` is read from a zeroed copy instead.
    func zeroed<T>(_ type: T.Type) -> T {
        let pointer = UnsafeMutableRawPointer.allocate(byteCount: MemoryLayout<T>.size, alignment: MemoryLayout<T>.alignment)
        defer { pointer.deallocate() }
        memset(pointer, 0, MemoryLayout<T>.size)
        return pointer.load(as: T.self)
    }

    // MARK: - Struct size matches the wire size

    func testStructSizesMatchWireSizes() {
        XCTAssertEqual(MemoryLayout<SP_MESSAGE>.size, 84)
        XCTAssertEqual(MemoryLayout<SP_PLAYER_INFO>.size, 4)
        XCTAssertEqual(MemoryLayout<SP_KILLS>.size, 8)
        XCTAssertEqual(MemoryLayout<SP_PLAYER>.size, 12)
        XCTAssertEqual(MemoryLayout<SP_TORP_INFO>.size, 8)
        XCTAssertEqual(MemoryLayout<SP_TORP>.size, 12)
        XCTAssertEqual(MemoryLayout<SP_LASER>.size, 16)
        XCTAssertEqual(MemoryLayout<SP_PLASMA_INFO>.size, 8)
        XCTAssertEqual(MemoryLayout<SP_PLASMA>.size, 12)
        XCTAssertEqual(MemoryLayout<SP_MOTD>.size, 84)
        XCTAssertEqual(MemoryLayout<SP_YOU>.size, 32)
        XCTAssertEqual(MemoryLayout<SP_QUEUE>.size, 4)
        XCTAssertEqual(MemoryLayout<SP_PLANET>.size, 12)
        XCTAssertEqual(MemoryLayout<SP_PICKOK>.size, 4)
        XCTAssertEqual(MemoryLayout<SP_LOGIN>.size, 104)
        XCTAssertEqual(MemoryLayout<SP_FLAGS>.size, 8)
        XCTAssertEqual(MemoryLayout<SP_MASK>.size, 4)
        XCTAssertEqual(MemoryLayout<SP_PLAYER_STATUS>.size, 4)
        XCTAssertEqual(MemoryLayout<SP_HOSTILE>.size, 4)
        XCTAssertEqual(MemoryLayout<SP_STATS>.size, 56)
        XCTAssertEqual(MemoryLayout<SP_PL_LOGIN>.size, 52)
        XCTAssertEqual(MemoryLayout<SP_PLANET_LOC>.size, 28)
    }

    func testDeclaredSizesMatchStructSizes() {
        XCTAssertEqual(zeroed(SP_MESSAGE.self).size, MemoryLayout<SP_MESSAGE>.size)
        XCTAssertEqual(zeroed(SP_PLAYER_INFO.self).size, MemoryLayout<SP_PLAYER_INFO>.size)
        XCTAssertEqual(zeroed(SP_KILLS.self).size, MemoryLayout<SP_KILLS>.size)
        XCTAssertEqual(zeroed(SP_PLAYER.self).size, MemoryLayout<SP_PLAYER>.size)
        XCTAssertEqual(zeroed(SP_TORP_INFO.self).size, MemoryLayout<SP_TORP_INFO>.size)
        XCTAssertEqual(zeroed(SP_TORP.self).size, MemoryLayout<SP_TORP>.size)
        XCTAssertEqual(zeroed(SP_LASER.self).size, MemoryLayout<SP_LASER>.size)
        XCTAssertEqual(zeroed(SP_PLASMA_INFO.self).size, MemoryLayout<SP_PLASMA_INFO>.size)
        XCTAssertEqual(zeroed(SP_PLASMA.self).size, MemoryLayout<SP_PLASMA>.size)
        XCTAssertEqual(zeroed(SP_MOTD.self).size, MemoryLayout<SP_MOTD>.size)
        XCTAssertEqual(zeroed(SP_YOU.self).size, MemoryLayout<SP_YOU>.size)
        XCTAssertEqual(zeroed(SP_QUEUE.self).size, MemoryLayout<SP_QUEUE>.size)
        XCTAssertEqual(zeroed(SP_PLANET.self).size, MemoryLayout<SP_PLANET>.size)
        XCTAssertEqual(zeroed(SP_PICKOK.self).size, MemoryLayout<SP_PICKOK>.size)
        XCTAssertEqual(zeroed(SP_LOGIN.self).size, MemoryLayout<SP_LOGIN>.size)
        XCTAssertEqual(zeroed(SP_FLAGS.self).size, MemoryLayout<SP_FLAGS>.size)
        XCTAssertEqual(zeroed(SP_MASK.self).size, MemoryLayout<SP_MASK>.size)
        XCTAssertEqual(zeroed(SP_PLAYER_STATUS.self).size, MemoryLayout<SP_PLAYER_STATUS>.size)
        XCTAssertEqual(zeroed(SP_HOSTILE.self).size, MemoryLayout<SP_HOSTILE>.size)
        XCTAssertEqual(zeroed(SP_STATS.self).size, MemoryLayout<SP_STATS>.size)
        XCTAssertEqual(zeroed(SP_PL_LOGIN.self).size, MemoryLayout<SP_PL_LOGIN>.size)
        XCTAssertEqual(zeroed(SP_PLANET_LOC.self).size, MemoryLayout<SP_PLANET_LOC>.size)
    }

    // MARK: - Field offsets

    func testSpMessageOffsets() {
        XCTAssertEqual(offset(\SP_MESSAGE.flags), 1)
        XCTAssertEqual(offset(\SP_MESSAGE.recpt), 2)
        XCTAssertEqual(offset(\SP_MESSAGE.from), 3)
        XCTAssertEqual(offset(\SP_MESSAGE.message), 4)
    }

    func testSpPlayerInfoOffsets() {
        XCTAssertEqual(offset(\SP_PLAYER_INFO.playerNum), 1)
        XCTAssertEqual(offset(\SP_PLAYER_INFO.shipType), 2)
        XCTAssertEqual(offset(\SP_PLAYER_INFO.team), 3)
    }

    func testSpKillsOffsets() {
        XCTAssertEqual(offset(\SP_KILLS.playerNum), 1)
        XCTAssertEqual(offset(\SP_KILLS.kills), 4)
    }

    func testSpPlayerOffsets() {
        XCTAssertEqual(offset(\SP_PLAYER.playerNum), 1)
        XCTAssertEqual(offset(\SP_PLAYER.directionNetrek), 2)
        XCTAssertEqual(offset(\SP_PLAYER.speed), 3)
        XCTAssertEqual(offset(\SP_PLAYER.positionX), 4)
        XCTAssertEqual(offset(\SP_PLAYER.positionY), 8)
    }

    func testSpTorpInfoOffsets() {
        XCTAssertEqual(offset(\SP_TORP_INFO.war), 1)
        XCTAssertEqual(offset(\SP_TORP_INFO.status), 2)
        XCTAssertEqual(offset(\SP_TORP_INFO.torpedoNumber), 4)
        XCTAssertEqual(offset(\SP_TORP_INFO.pad2), 6)
    }

    func testSpTorpOffsets() {
        XCTAssertEqual(offset(\SP_TORP.direction), 1)
        XCTAssertEqual(offset(\SP_TORP.torpedoNum), 2)
        XCTAssertEqual(offset(\SP_TORP.positionX), 4)
        XCTAssertEqual(offset(\SP_TORP.positionY), 8)
    }

    func testSpLaserOffsets() {
        XCTAssertEqual(offset(\SP_LASER.laserID), 1)
        XCTAssertEqual(offset(\SP_LASER.status), 2)
        XCTAssertEqual(offset(\SP_LASER.direction), 3)
        XCTAssertEqual(offset(\SP_LASER.positionX), 4)
        XCTAssertEqual(offset(\SP_LASER.positionY), 8)
        XCTAssertEqual(offset(\SP_LASER.target), 12)
    }

    func testSpPlasmaInfoOffsets() {
        XCTAssertEqual(offset(\SP_PLASMA_INFO.war), 1)
        XCTAssertEqual(offset(\SP_PLASMA_INFO.status), 2)
        XCTAssertEqual(offset(\SP_PLASMA_INFO.plasmaNumber), 4)
        XCTAssertEqual(offset(\SP_PLASMA_INFO.pad2), 6)
    }

    func testSpPlasmaOffsets() {
        XCTAssertEqual(offset(\SP_PLASMA.direction), 1)
        XCTAssertEqual(offset(\SP_PLASMA.plasmaNum), 2)
        XCTAssertEqual(offset(\SP_PLASMA.positionX), 4)
        XCTAssertEqual(offset(\SP_PLASMA.positionY), 8)
    }

    func testSpMotdOffsets() {
        XCTAssertEqual(offset(\SP_MOTD.motd), 4)
    }

    func testSpYouOffsets() {
        XCTAssertEqual(offset(\SP_YOU.playerNum), 1)
        XCTAssertEqual(offset(\SP_YOU.hostile), 2)
        XCTAssertEqual(offset(\SP_YOU.war), 3)
        XCTAssertEqual(offset(\SP_YOU.armies), 4)
        XCTAssertEqual(offset(\SP_YOU.tractor), 5)
        XCTAssertEqual(offset(\SP_YOU.flags), 8)
        XCTAssertEqual(offset(\SP_YOU.damage), 12)
        XCTAssertEqual(offset(\SP_YOU.shield), 16)
        XCTAssertEqual(offset(\SP_YOU.fuel), 20)
        XCTAssertEqual(offset(\SP_YOU.etmp), 24)
        XCTAssertEqual(offset(\SP_YOU.wtmp), 26)
        XCTAssertEqual(offset(\SP_YOU.whydead), 28)
        XCTAssertEqual(offset(\SP_YOU.whodead), 30)
    }

    func testSpQueueOffsets() {
        XCTAssertEqual(offset(\SP_QUEUE.position), 2)
    }

    func testSpPlanetOffsets() {
        XCTAssertEqual(offset(\SP_PLANET.planetNum), 1)
        XCTAssertEqual(offset(\SP_PLANET.owner), 2)
        XCTAssertEqual(offset(\SP_PLANET.info), 3)
        XCTAssertEqual(offset(\SP_PLANET.flags), 4)
        XCTAssertEqual(offset(\SP_PLANET.armies), 8)
    }

    func testSpPickOkOffsets() {
        XCTAssertEqual(offset(\SP_PICKOK.state), 1)
    }

    func testSpLoginOffsets() {
        XCTAssertEqual(offset(\SP_LOGIN.accept), 1)
        XCTAssertEqual(offset(\SP_LOGIN.paradise1), 2)
        XCTAssertEqual(offset(\SP_LOGIN.paradise2), 3)
        XCTAssertEqual(offset(\SP_LOGIN.flags), 4)
        XCTAssertEqual(offset(\SP_LOGIN.keymap), 8)
        XCTAssertEqual(MemoryLayout.size(ofValue: SP_LOGIN(success: true).keymap), 96)
    }

    func testSpFlagsOffsets() {
        XCTAssertEqual(offset(\SP_FLAGS.playerID), 1)
        XCTAssertEqual(offset(\SP_FLAGS.tractor), 2)
        XCTAssertEqual(offset(\SP_FLAGS.flags), 4)
    }

    func testSpMaskOffsets() {
        XCTAssertEqual(offset(\SP_MASK.mask), 1)
    }

    func testSpPlayerStatusOffsets() {
        XCTAssertEqual(offset(\SP_PLAYER_STATUS.playerNum), 1)
        XCTAssertEqual(offset(\SP_PLAYER_STATUS.status), 2)
    }

    func testSpHostileOffsets() {
        XCTAssertEqual(offset(\SP_HOSTILE.playerID), 1)
        XCTAssertEqual(offset(\SP_HOSTILE.war), 2)
        XCTAssertEqual(offset(\SP_HOSTILE.hostile), 3)
    }

    func testSpStatsOffsets() {
        XCTAssertEqual(offset(\SP_STATS.playerID), 1)
        XCTAssertEqual(offset(\SP_STATS.tournamentKills), 4)
        XCTAssertEqual(offset(\SP_STATS.tournamentLosses), 8)
        XCTAssertEqual(offset(\SP_STATS.overallKills), 12)
        XCTAssertEqual(offset(\SP_STATS.overallLosses), 16)
        XCTAssertEqual(offset(\SP_STATS.tournamentTicks), 20)
        XCTAssertEqual(offset(\SP_STATS.tournamentPlanets), 24)
        XCTAssertEqual(offset(\SP_STATS.tournamentArmies), 28)
        XCTAssertEqual(offset(\SP_STATS.starbaseKills), 32)
        XCTAssertEqual(offset(\SP_STATS.starbaseLosses), 36)
        XCTAssertEqual(offset(\SP_STATS.intramuralArmies), 40)
        XCTAssertEqual(offset(\SP_STATS.intramuralPlanets), 44)
        XCTAssertEqual(offset(\SP_STATS.maxKills100), 48)
        XCTAssertEqual(offset(\SP_STATS.starbaseMaxKills100), 52)
    }

    func testSpPlLoginOffsets() {
        XCTAssertEqual(offset(\SP_PL_LOGIN.playerNum), 1)
        XCTAssertEqual(offset(\SP_PL_LOGIN.rank), 2)
        XCTAssertEqual(offset(\SP_PL_LOGIN.name), 4)
        XCTAssertEqual(offset(\SP_PL_LOGIN.monitor), 20)
        XCTAssertEqual(offset(\SP_PL_LOGIN.login), 36)
    }

    func testSpPlanetLocOffsets() {
        XCTAssertEqual(offset(\SP_PLANET_LOC.planetID), 1)
        XCTAssertEqual(offset(\SP_PLANET_LOC.positionX), 4)
        XCTAssertEqual(offset(\SP_PLANET_LOC.positionY), 8)
        XCTAssertEqual(offset(\SP_PLANET_LOC.name), 12)
    }
}
