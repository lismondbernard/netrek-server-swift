import XCTest
@testable import netrek_server_swift

// The metaserver report, byte by byte, against what vanilla's solicit() would
// send for the same universe (quozl/netrek-server ntserv/solicit.c:370-382):
//
//   sprintf(here, "%s\n%s\n%s\n%d\n%d\n%d\n%d\n%s\n%s\n%s\n%s\n",
//           "b", m->ours, m->type, m->pport, m->oport, nplayers, nfree,
//           status->tourn ? "y" : "n", isrsa ? "y" : "n",
//           gamefull ? "y" : "n", m->comment);
final class MetaserverReportTests: XCTestCase {
    /// An empire server with 3 humans on it, not in t-mode.
    private let example = MetaserverReport(domainName: "netrek.example.org", gameStyle: .empire,
                                           players: 3, tournamentMode: false)

    /// What solicit.c's sprintf makes from these values.
    private func vanilla(ours: String, type: String, pport: Int, oport: Int, nplayers: Int, nfree: Int,
                         tourn: Bool, isrsa: Bool, gamefull: Bool, comment: String) -> [UInt8] {
        var text = ""
        text += "b" + "\n"
        text += ours + "\n"
        text += type + "\n"
        text += String(pport) + "\n"
        text += String(oport) + "\n"
        text += String(nplayers) + "\n"
        text += String(nfree) + "\n"
        text += (tourn ? "y" : "n") + "\n"
        text += (isrsa ? "y" : "n") + "\n"
        text += (gamefull ? "y" : "n") + "\n"
        text += comment + "\n"
        return Array(text.utf8)
    }

    func testReportBytesForAnExampleUniverse() {
        let expected = Array("b\nnetrek.example.org\nE\n2592\n0\n3\n13\nn\nn\nn\nSwift-IPv6-empire\n".utf8)
        XCTAssertEqual(Array(example.text.utf8), expected)
        XCTAssertEqual(example.text.utf8.count, 59)
        XCTAssertEqual(Array(example.text.utf8),
                       vanilla(ours: "netrek.example.org", type: "E", pport: 2592, oport: 0, nplayers: 3, nfree: 13,
                               tourn: false, isrsa: false, gamefull: false, comment: "Swift-IPv6-empire"))
    }

    func testReportFieldByField() {
        // Split the way the metaserver reads it: strtok on "\n" (scan.c:999-1152).
        let lines = example.text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        XCTAssertEqual(lines.count, 12, "11 fields, each ending in a newline")
        XCTAssertEqual(lines.last, "", "the report ends in a newline")
        let names = ["version", "address", "type", "port", "observer port", "players", "free",
                     "t-mode", "RSA", "full", "comment"]
        let expected = ["b", "netrek.example.org", "E", "2592", "0", "3", "13", "n", "n", "n", "Swift-IPv6-empire"]
        for (index, name) in names.enumerated() {
            XCTAssertEqual(lines[index], expected[index], name)
        }
        XCTAssertEqual(example.fields, expected)
    }

    func testCommentIsOneLine() {
        // The comment had a newline in it ("Swift-IPv6\n-empire"), so the
        // metaserver took "Swift-IPv6" as the comment and "-empire" as the
        // first line of the player list.
        for style in [GameStyle.bronco, .empire] {
            let report = MetaserverReport(domainName: "netrek.example.org", gameStyle: style, players: 0, tournamentMode: false)
            XCTAssertFalse(report.comment.contains("\n"), "\(style)")
            XCTAssertLessThan(report.comment.utf8.count, 32, "vanilla keeps 32 bytes of comment (solicit.h:39)")
            XCTAssertTrue(report.text.hasSuffix(report.comment + "\n"), "\(style)")
        }
    }

    func testBroncoInTModeAndFull() {
        let report = MetaserverReport(domainName: "bronco.example.org", gameStyle: .bronco, players: 17, tournamentMode: true)
        XCTAssertEqual(Array(report.text.utf8),
                       vanilla(ours: "bronco.example.org", type: "B", pport: 2592, oport: 0, nplayers: 17, nfree: 0,
                               tourn: true, isrsa: false, gamefull: true, comment: "Swift-IPv6-bronco"))
    }

    func testTypeLetters() {
        // Bronco reports "B", as vanilla does (docs/sample_metaservers:23).
        // Empire reports "E", which the metaserver keeps and COW shows as "Empire".
        let bronco = MetaserverReport(domainName: "a.example", gameStyle: .bronco, players: 0, tournamentMode: false)
        let empire = MetaserverReport(domainName: "a.example", gameStyle: .empire, players: 0, tournamentMode: false)
        XCTAssertEqual(bronco.typeLetter, "B")
        XCTAssertEqual(empire.typeLetter, "E")
        // The metaserver reads only the first character of the type line (scan.c:1076).
        XCTAssertEqual(bronco.fields[2].count, 1)
        XCTAssertEqual(empire.fields[2].count, 1)
    }

    func testEmptyServer() {
        let report = MetaserverReport(domainName: "netrek.example.org", gameStyle: .empire, players: 0, tournamentMode: false)
        XCTAssertEqual(report.text, "b\nnetrek.example.org\nE\n2592\n0\n0\n16\nn\nn\nn\nSwift-IPv6-empire\n")
    }
}
