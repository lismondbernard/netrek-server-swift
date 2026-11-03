//
//  MetaserverUDP.swift
//  netrek-server-swift
//
//  Created by Darrell Root on 7/14/20.
//

import Foundation
import NIO
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

/// One metaserver to report to: a host name (or numeric address) and a UDP port.
struct MetaserverHost: Equatable, CustomStringConvertible {
    /// The UDP port metaservers listen on for server reports
    /// (quozl/netrek-metaserver scan.c:946, USOCKPORT).
    static let defaultPort = 3521

    let name: String
    let port: Int

    /// The metaservers vanilla lists in its sample configuration
    /// (quozl/netrek-server docs/sample_metaservers:23-25).
    static let defaultNames = [
        "metaserver.us.netrek.org",
        "metaserver2.us.netrek.org",
        "metaserver3.us.netrek.org",
    ]

    init(name: String, port: Int = MetaserverHost.defaultPort) {
        self.name = name
        self.port = port
    }

    /// Reads "name" or "name:port", as given to --metaserver.
    init?(argument: String) {
        let parts = argument.split(separator: ":", omittingEmptySubsequences: false)
        switch parts.count {
        case 1 where !parts[0].isEmpty:
            self.init(name: String(parts[0]))
        case 2 where !parts[0].isEmpty:
            guard let port = Int(parts[1]), (1...65535).contains(port) else { return nil }
            self.init(name: String(parts[0]), port: port)
        default:
            return nil
        }
    }

    var description: String {
        return port == MetaserverHost.defaultPort ? name : "\(name):\(port)"
    }
}

/// Sends the server's report to the metaservers over UDP.
///
/// Host names are looked up each time a report is sent, as the addresses
/// behind them change over the years. The lookup can take seconds, so it
/// runs on a queue of its own and never on the game loop.
class MetaserverUDP {
    typealias Resolver = (MetaserverHost) -> SocketAddress?

    let hosts: [MetaserverHost]
    private let resolve: Resolver
    private let group: EventLoopGroup
    private let ownsGroup: Bool
    private let channel: Channel
    private let lookupQueue = DispatchQueue(label: "metaserver-lookup")

    /// - Parameters:
    ///   - hosts: the metaservers to send to.
    ///   - group: the event loop group for the UDP socket. One is made if nil.
    ///   - resolve: looks up one host. Tests can pass their own.
    init?(hosts: [MetaserverHost], group: EventLoopGroup? = nil, resolve: @escaping Resolver = MetaserverUDP.resolveIPv4) {
        self.hosts = hosts
        self.resolve = resolve
        self.ownsGroup = group == nil
        let group = group ?? MultiThreadedEventLoopGroup(numberOfThreads: 1)
        self.group = group
        // IPv4 only, as vanilla (ntserv/solicit.c:54, AF_INET): the metaserver
        // reads the sender's address as a sockaddr_in (scan.c:952).
        do {
            self.channel = try DatagramBootstrap(group: group)
                .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
                .bind(host: "0.0.0.0", port: 0)
                .wait()
        } catch {
            logger.error("Metaserver reports are off: unable to open a UDP socket: \(error)")
            if ownsGroup { try? group.syncShutdownGracefully() }
            return nil
        }
    }

    deinit {
        channel.close(promise: nil)
        if ownsGroup {
            group.shutdownGracefully { _ in }
        }
    }

    /// Sends a report to every metaserver whose name resolves. Two names that
    /// resolve to the same address get one packet, since the metaserver delists
    /// a server that reports twice within 58 seconds (scan.c:1231-1245).
    /// Returns at once. `completion`, if given, runs on the lookup queue once the
    /// packets are handed to the socket, with the addresses they went to.
    func send(report: String, completion: (([SocketAddress]) -> Void)? = nil) {
        let hosts = self.hosts
        lookupQueue.async {
            var sentTo: [SocketAddress] = []
            for host in hosts {
                guard let address = self.resolve(host) else {
                    logger.warning("Metaserver \(host) did not resolve; report not sent there")
                    continue
                }
                guard !sentTo.contains(address) else {
                    logger.info("Metaserver \(host) is \(address), already sent to; skipped")
                    continue
                }
                let buffer = self.channel.allocator.buffer(string: report)
                let envelope = AddressedEnvelope<ByteBuffer>(remoteAddress: address, data: buffer)
                self.channel.writeAndFlush(envelope).whenFailure { error in
                    logger.error("Metaserver report to \(host) (\(address)) failed: \(error)")
                }
                sentTo.append(address)
                logger.info("Metaserver report sent to \(host) (\(address))")
            }
            completion?(sentTo)
        }
    }

    /// Looks up the first IPv4 address of a host with getaddrinfo, which works
    /// the same on Linux and macOS. It blocks, so call it off the game loop.
    static func resolveIPv4(_ host: MetaserverHost) -> SocketAddress? {
        var hints = addrinfo()
        hints.ai_family = AF_INET
        #if os(Linux)
        hints.ai_socktype = Int32(SOCK_DGRAM.rawValue)
        #else
        hints.ai_socktype = SOCK_DGRAM
        #endif
        var result: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host.name, String(host.port), &hints, &result) == 0, let first = result else {
            return nil
        }
        defer { freeaddrinfo(first) }
        var entry: UnsafeMutablePointer<addrinfo>? = first
        while let info = entry {
            if info.pointee.ai_family == AF_INET, let address = info.pointee.ai_addr {
                let ipv4 = address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                return SocketAddress(ipv4, host: host.name)
            }
            entry = info.pointee.ai_next
        }
        return nil
    }

    /// The report for this universe, sent by the game loop.
    func makeReport(universe: Universe) -> String {
        guard let domainName = netrekOptions.domainName else { return "" }
        var returnValue = ""
        returnValue += "b\n"  // version
        returnValue += "\(domainName)\n" //netrek server DNS name
        switch netrekOptions.gameStyle {
        case .bronco:
            returnValue += "B\n"  // type
        case .empire:
            returnValue += "E\n"  // type
        }
        returnValue += "2592\n" // netrek server port
        returnValue += "0\n"
        let playerCount = universe.players.filter({$0.status != .free && $0.robot == nil}).count
        returnValue += "\(playerCount)\n"
        let freeCount = max(16 - playerCount,0)
        returnValue += "\(freeCount)\n"
        let tMode: String
        switch universe.gameState {
        case .intramural:
            tMode = "n"
        case .tmode:
            tMode = "y"
        }
        returnValue += "\(tMode)\n"
        returnValue += "n\n" //RSA
        if playerCount >= 16 {
            returnValue += "y\n" //gamefull
        } else {
            returnValue += "n\n" // gamefull
        }
        switch netrekOptions.gameStyle {
        case .bronco:
            returnValue += "Swift-IPv6-bronco\n" // comment
        case .empire:
            returnValue += "Swift-IPv6\n-empire" // comment
        }

        /* The detailed user list was not picked up by the metaserver successfully.  Rather than debug I chose not to share this information

        for player in universe.players.filter({$0.status != .free}) {
            returnValue += "\(player.slot.hex)\n"
            returnValue += "\(player.team.letter)\n"
            returnValue += "\(player.ship.rawValue)\n"
            if let user = player.user {
                returnValue += "\(user.rank.value)\n"
                returnValue += "\(user.name)\n"
                returnValue += "\(user.userinfo)\n"
            } else {
                returnValue += "0\n"
                returnValue += "unknownName\n"
                returnValue += "unknownInfo\n"
            }
            returnValue += "redacted\n" // user host
        }*/
        logger.debug("metaserver report \(returnValue)")
        return returnValue
    }
}

/*private final class MetaSender: ChannelOutboundHandler {
    public typealias OutboundIn = AddressedEnvelope<ByteBuffer>
    private var context: ChannelHandlerContext?

    public func channelActive(context: ChannelHandlerContext) {
        self.context = context
        logger.info("\(#file) \(#function)")
    }

    public func sendMessage(string: String, host: String, port: Int) {
        guard let context = self.context else {
            logger.error("\(#file) \(#function) Error: context nil")
            return
        }
        guard let remoteAddress = try? SocketAddress.makeAddressResolvingHost(host, port: port) else {
            logger.error("\(#file) \(#function) Error: unable to resolve host \(host)")
            return
        }
        let buffer = context.channel.allocator.buffer(string: string)
        let envelope = AddressedEnvelope<ByteBuffer>(remoteAddress: remoteAddress, data: buffer)
        _ = context.channel.writeAndFlush(envelope)

    }
}*/
