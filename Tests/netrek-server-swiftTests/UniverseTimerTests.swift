import XCTest
@testable import netrek_server_swift

// Universe.timerFired cannot run under test: a Universe reads netrekOptions,
// which main.swift creates, and starts the game timer and Bonjour. So this
// checks the condition timerFired uses for its once per minute block
// (player.minuteTimerFired, which sends SP_STATS and checks for ghosts).
final class UniverseTimerTests: XCTestCase {
    /// The ticks, counting from 1 as timerFired does, where the minute block runs.
    private func minuteTicks(seconds: Int, updatesPerSecond: Double) -> [Int] {
        let ticks = seconds * Int(updatesPerSecond)
        return (1...ticks).filter { Universe.isOncePerMinute(timerCount: $0, updatesPerSecond: updatesPerSecond) }
    }

    func testMinuteBlockRunsOnceAMinute() {
        // The server runs at 20 updates a second: two minutes is 2400 ticks.
        XCTAssertEqual(minuteTicks(seconds: 120, updatesPerSecond: 20), [1200, 2400])
    }

    func testMinuteBlockFollowsTheUpdateRate() {
        XCTAssertEqual(minuteTicks(seconds: 120, updatesPerSecond: 10), [600, 1200])
    }
}
