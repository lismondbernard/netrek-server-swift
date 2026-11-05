import XCTest
@testable import netrek_server_swift

// Weapon and engine heat as classic has it (SSS-304, SSS-305; the same
// fix as NetrekServerLib). quozl/netrek-server at 43b641f:
// ntserv/daemon.c udplayers_palive_cool_weapons and _cool_engines (lines
// 1520-1557), run every 0.1 s; limits from ntserv/getship.c.
//
// Player.shortTimerFired cannot run under test (see UniverseTimerTests),
// so these check the rule it uses each 0.1 s: OverheatLock, and the
// cooling step.
final class OverheatTests: XCTestCase {
    private let always: (Range<Int>) -> Int = { $0.lowerBound }   // the 1 in 40 comes up; shortest lock
    private let never: (Range<Int>) -> Int = { $0.upperBound - 1 } // the 1 in 40 never comes up

    func testHeatLimitsAreClassics() {
        for ship in [ShipType.scout, .destroyer, .cruiser, .battleship, .assault, .starbase] {
            XCTAssertEqual(ship.maxWeaponTemp, ship == .starbase ? 1300 : 1000, "\(ship) weapons")
            XCTAssertEqual(ship.maxEngineTemp, ship == .assault ? 1200 : 1000, "\(ship) engines")
        }
    }

    /// Before, cooling was weaponCoolRate / 20 a tick in whole numbers, so
    /// 30 a second came out as 20. Each 0.1 s step is exact.
    func testWeaponsCoolAtTheShipsRate() {
        for ship in [ShipType.scout, .destroyer, .cruiser, .battleship, .assault, .starbase] {
            XCTAssertEqual(Player.weaponCoolingPerTenth(ship) * 10, ship.weaponCoolRate, "\(ship)")
        }
        XCTAssertEqual(Player.weaponCoolingPerTenth(.battleship), 3)
        XCTAssertEqual(Player.weaponCoolingPerTenth(.scout), 3)
    }

    func testNoLockAtTheLimit() {
        var lock = OverheatLock()
        XCTAssertFalse(lock.step(heat: 1000, limit: 1000, roll: always))
    }

    func testOverTheLimitTheLockMayNotComeYet() {
        var lock = OverheatLock()
        for _ in 0..<100 {
            XCTAssertFalse(lock.step(heat: 1500, limit: 1000, roll: never))
        }
    }

    func testLockLastsItsTimeWhateverTheHeat() {
        var lock = OverheatLock()
        XCTAssertTrue(lock.step(heat: 1010, limit: 1000, roll: always), "Locks over the limit")
        for tenth in 1..<100 {
            XCTAssertTrue(lock.step(heat: 0, limit: 1000, roll: always), "Still locked at \(tenth) tenths, though cold")
        }
        XCTAssertFalse(lock.step(heat: 0, limit: 1000, roll: always), "Lifted after 10 s")
    }

    func testLongestLockIs249Tenths() {
        var calls = 0
        let longest: (Range<Int>) -> Int = { range in calls += 1; return calls == 2 ? range.upperBound - 1 : range.lowerBound }
        var lock = OverheatLock()
        XCTAssertTrue(lock.step(heat: 1310, limit: 1300, roll: longest))
        for _ in 1..<249 { XCTAssertTrue(lock.step(heat: 1310, limit: 1300, roll: longest)) }
        XCTAssertFalse(lock.step(heat: 0, limit: 1300, roll: longest))
    }

    func testStarbaseRunsHotterThanOtherShips() {
        var lock = OverheatLock()
        XCTAssertFalse(lock.step(heat: 1250, limit: ShipType.starbase.maxWeaponTemp, roll: always))
        XCTAssertTrue(lock.step(heat: 1250, limit: ShipType.cruiser.maxWeaponTemp, roll: always))
    }
}
