//
//  MetaserverReport.swift
//  netrek-server-swift
//
//  The report text from Darrell Root's MetaserverUDP.makeReport, moved here
//  so it can be built without a Universe and checked byte by byte.
//

import Foundation

/// The status report sent to the metaservers, in metaserver format version "b".
///
/// Each field is one line ending in "\n", in the order vanilla writes them
/// (quozl/netrek-server ntserv/solicit.c:370-382) and the metaserver reads
/// them (quozl/netrek-metaserver scan.c:998-1152). The per-player list that
/// can follow the comment (solicit.c:400-436) is not sent.
struct MetaserverReport: Equatable {
    /// The name the metaserver lists the server under (--domain-name).
    var domainName: String
    var gameStyle: GameStyle
    /// Human players. Robots are not counted, as in vanilla
    /// (slots_playing, ntserv/slotmaint.c:167-178, skips robots).
    var players: Int
    var tournamentMode: Bool
    /// The port players connect to.
    var port: Int = Globals.PORT

    /// The comment field. The metaserver keeps it whole only if it has no
    /// newline in it (scan.c:1149, strtok on "\n").
    var comment: String {
        switch gameStyle {
        case .bronco:
            return "Swift-IPv6-bronco"
        case .empire:
            return "Swift-IPv6-empire"
        }
    }

    var typeLetter: String {
        switch gameStyle {
        case .bronco:
            return "B"
        case .empire:
            return "E"
        }
    }

    var freeSlots: Int {
        return max(16 - players, 0)
    }

    var gameFull: Bool {
        return players >= 16
    }

    /// The fields in order, each without its "\n".
    var fields: [String] {
        return [
            "b",                            // version
            domainName,                     // address
            typeLetter,                     // type
            "\(port)",                      // port
            "0",                            // observer port: this server has none
            "\(players)",                   // players
            "\(freeSlots)",                 // free slots
            tournamentMode ? "y" : "n",     // t-mode
            "n",                            // RSA
            gameFull ? "y" : "n",           // full
            comment,                        // comment
        ]
    }

    /// The report as sent: every field followed by "\n", as vanilla's
    /// sprintf format "%s\n%s\n%s\n%d\n%d\n%d\n%d\n%s\n%s\n%s\n%s\n".
    var text: String {
        return fields.map { $0 + "\n" }.joined()
    }
}

extension MetaserverReport {
    /// The report for a universe as it is now.
    init(universe: Universe, domainName: String, gameStyle: GameStyle) {
        self.init(domainName: domainName,
                  gameStyle: gameStyle,
                  players: universe.players.filter({ $0.status != .free && $0.robot == nil }).count,
                  tournamentMode: universe.gameState == .tmode)
    }
}
