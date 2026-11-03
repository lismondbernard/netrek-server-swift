import XCTest
@testable import netrek_server_swift

// The metaserver send schedule with a stepped clock. The game loop checks it
// once a second, so these step one second at a time.
final class MetaserverScheduleTests: XCTestCase {
    private func report(players: Int) -> String {
        return MetaserverReport(domainName: "netrek.example.org", gameStyle: .empire,
                                players: players, tournamentMode: false).text
    }

    /// Runs the schedule once a second from 0 to `seconds`, with the player
    /// count changing at the given times. Returns the seconds a report went out.
    private func sendTimes(seconds: Int, step: Double = 1, playersFrom changes: [Int: Int]) -> [Double] {
        var schedule = MetaserverSchedule()
        var players = 0
        var sent: [Double] = []
        var tick = 0
        while Double(tick) * step <= Double(seconds) {
            let now = Double(tick) * step
            if Double(Int(now)) == now, let count = changes[Int(now)] { players = count }
            if schedule.check(report(players: players), now: now) { sent.append(now) }
            tick += 1
        }
        return sent
    }

    func testFirstReportGoesOutAtOnce() {
        var schedule = MetaserverSchedule()
        XCTAssertTrue(schedule.check(report(players: 0), now: 1234))
    }

    func testNothingChangesThenEvery900Seconds() {
        XCTAssertEqual(sendTimes(seconds: 3600, playersFrom: [:]), [0, 900, 1800, 2700, 3600])
    }

    func testAChangeWaitsForTheMinimumOf60Seconds() {
        // A player joins 10 seconds after the first report.
        XCTAssertEqual(sendTimes(seconds: 120, playersFrom: [10: 1]), [0, 60])
    }

    func testAChangeAfterTheMinimumGoesOutAtOnce() {
        // A player joins 500 seconds after the first report.
        XCTAssertEqual(sendTimes(seconds: 600, playersFrom: [500: 1]), [0, 500])
    }

    func testAChangeThatIsUndoneInTimeIsNotSent() {
        // A player joins at 10 and leaves at 30: by 60 the report is the same
        // as the one sent at 0, so nothing goes until the 900 second report.
        XCTAssertEqual(sendTimes(seconds: 1000, playersFrom: [10: 1, 30: 0]), [0, 900])
    }

    func testAnHourOfPlay() {
        let changes = [5: 1, 10: 2, 200: 3, 205: 4, 2000: 3]
        let sent = sendTimes(seconds: 3600, playersFrom: changes)
        XCTAssertEqual(sent, [0, 60, 200, 260, 1160, 2000, 2900])
        for (earlier, later) in zip(sent, sent.dropFirst()) {
            XCTAssertGreaterThanOrEqual(later - earlier, 60, "reports at \(earlier) and \(later) are too close")
            XCTAssertLessThanOrEqual(later - earlier, 900, "no report between \(earlier) and \(later)")
        }
    }

    func testCheckedEveryGameTickTheMinimumStillHolds() {
        // At 20 checks a second, a player count that changes every second.
        var changes: [Int: Int] = [:]
        for second in 0...600 { changes[second] = second % 2 }
        let sent = sendTimes(seconds: 600, step: 0.05, playersFrom: changes)
        XCTAssertEqual(sent.first, 0)
        for (earlier, later) in zip(sent, sent.dropFirst()) {
            XCTAssertGreaterThanOrEqual(later - earlier, 60)
        }
    }

    func testIntervalsMatchVanilla() {
        // META_MINIMUM_DELAY and META_MAXIMUM_DELAY, include/solicit.h:18 and 22.
        XCTAssertEqual(MetaserverSchedule.minimumInterval, 60)
        XCTAssertEqual(MetaserverSchedule.maximumInterval, 900)
    }
}
