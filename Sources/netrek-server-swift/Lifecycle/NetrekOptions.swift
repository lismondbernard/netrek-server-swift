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
}
