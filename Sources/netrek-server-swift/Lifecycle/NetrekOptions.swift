//
//  NetrekOptions.swift
//  netrek-server-swift
//
//  Created by Darrell Root on 7/15/20.
//

import Foundation
import ArgumentParser

enum GameStyle: String, EnumerableFlag {
    case bronco
    case empire
}
struct NetrekOptions: ParsableCommand {
    @Option(help: "The fully qualified domainname of this netrek server for the metaserver to display")
    var domainName: String?
    
    @Option(help: "The directory to store netrek log files and user database.")
    var directory: String = "/tmp/netrek"
    
    @Flag(help: "Enables debug logging. Warning: fills up filesystems in a few hours.")
    var debug = false
    
    @Flag(help: "Specifies the Netrek Game Style.")
    var gameStyle: GameStyle = .empire

    @Option(help: "The address to listen on, for example 0.0.0.0 or ::. Default: :: (all addresses). If the default fails because this host has no IPv6, the server listens on 0.0.0.0 instead. An address given here is used as is, with no fallback.")
    var listenAddress: String?

    // Hidden: for the smoke test, which needs a free port. The metaserver report
    // and Bonjour still say 2592, so do not use it for a real server.
    @Option(help: .hidden)
    var port: Int = 2592

    @Option(name: .customLong("metaserver"), help: ArgumentHelp("A metaserver to report to, as a host name or name:port (port 3521 if left out). Give it more than once for more than one; the first one given replaces the defaults. Only used with --domain-name. Default: \(MetaserverHost.defaultNames.joined(separator: ", ")).", valueName: "host"))
    var metaservers: [String] = MetaserverHost.defaultNames

    /// The --metaserver values, read.
    var metaserverHosts: [MetaserverHost] {
        return metaservers.compactMap(MetaserverHost.init(argument:))
    }

    func validate() throws {
        for value in metaservers where MetaserverHost(argument: value) == nil {
            throw ValidationError("--metaserver \(value): give a host name, or name:port with a port from 1 to 65535.")
        }
    }
}
