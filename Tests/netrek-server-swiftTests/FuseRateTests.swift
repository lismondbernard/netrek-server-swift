import XCTest
@testable import netrek_server_swift

// Bombing, planet fire and army beaming must run as often as in classic,
// which counts them in 0.1 second steps whatever the frame rate (SSS-299):
// PLFIGHTFUSE 5 (every 0.5 s) for bombing and planet fire, BEAMFUSE 8
// (every 0.8 s) for beaming. quozl/netrek-server ntserv/daemon.c at
// 43b641f, lines 377-390, with fuse() at line 71.
//
// Player.shortTimerFired cannot run under test, for the same reason as
// Universe.timerFired (see UniverseTimerTests): it works on the universe
// that main.swift creates. So these check the condition shortTimerFired
// uses for each of the three, with the fuse it passes.
final class FuseRateTests: XCTestCase {
    /// How many ticks in `seconds` of play, counting from 1 as timerFired
    /// does, a check with this fuse runs on.
    private func calls(tenths: Int, seconds: Int, updatesPerSecond: Double) -> Int {
        let ticks = seconds * Int(updatesPerSecond)
        return (1...ticks).filter {
            Universe.isFuse(tenths: tenths, timerCount: $0, updatesPerSecond: updatesPerSecond)
        }.count
    }

    func testBombingRunsEveryHalfSecond() {
        XCTAssertEqual(calls(tenths: Player.planetFightFuse, seconds: 10, updatesPerSecond: 20), 20)
    }

    func testPlanetsFireEveryHalfSecond() {
        // The same fuse as bombing, as in classic's plfight().
        XCTAssertEqual(Player.planetFightFuse, 5)
        XCTAssertEqual(calls(tenths: Player.planetFightFuse, seconds: 10, updatesPerSecond: 20), 20)
    }

    /// 0.8 s is 16 ticks, and 200/16 = 12.5, so a 10 second window holds 12
    /// or 13 calls depending on where it starts. From tick 1 the calls are on
    /// ticks 16, 32, ... 192: 12.
    func testBeamingRunsEvery0_8Seconds() {
        XCTAssertEqual(calls(tenths: Player.beamFuse, seconds: 10, updatesPerSecond: 20), 12)
        // Starting the window half a beam later catches the 13th.
        let ticks = (9...208).filter { Universe.isFuse(tenths: Player.beamFuse, timerCount: $0, updatesPerSecond: 20) }
        XCTAssertEqual(ticks.count, 13)
    }

    /// Plasma tracking (Plasma.updatePosition) runs on a 1 tenth fuse, as
    /// classic turns plasmas only on 0.1 s boundaries (ntserv/daemon.c lines
    /// 2173-2175): every other tick here, 10 times a second.
    func testPlasmaTracksTenTimesASecond() {
        XCTAssertEqual(calls(tenths: 1, seconds: 1, updatesPerSecond: 20), 10)
    }

    /// Torpedo wobble (Torpedo.shortTimerFired) runs on a 1 tenth fuse too,
    /// as classic wobbles torpedoes only on 0.1 s boundaries
    /// (ntserv/daemon.c lines 2184-2188).
    func testTorpedoesWobbleTenTimesASecond() {
        let ticks = (1...20).filter { Universe.isFuse(tenths: 1, timerCount: $0, updatesPerSecond: 20) }
        XCTAssertEqual(ticks, [2, 4, 6, 8, 10, 12, 14, 16, 18, 20])
    }

    func testFusesFollowTheUpdateRate() {
        XCTAssertEqual(calls(tenths: Player.planetFightFuse, seconds: 10, updatesPerSecond: 10), 20)
        XCTAssertEqual(calls(tenths: Player.beamFuse, seconds: 10, updatesPerSecond: 10), 12)
    }
}
