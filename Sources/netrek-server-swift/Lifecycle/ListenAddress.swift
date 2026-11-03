//
//  ListenAddress.swift
//  netrek-server-swift
//

import Foundation
import NIO

/// Where the server listens, and when it may fall back to IPv4.
enum ListenAddress {
    /// Used when `--listen-address` is not given. All IPv6 addresses, and on most
    /// systems IPv4 too (Linux allows that unless `net.ipv6.bindv6only` is 1).
    static let defaultAddress = "::"
    /// Used only when the default fails because the host has no IPv6.
    static let ipv4Fallback = "0.0.0.0"

    /// True when an error from binding `::` means this host has no IPv6,
    /// as opposed to something like the port already being in use.
    static func isNoIPv6Error(_ error: Error) -> Bool {
        // getaddrinfo could not turn "::" into an address. glibc does this when
        // the host has no IPv6 address other than loopback, or no IPv6 at all.
        if case SocketAddressError.unknown = error {
            return true
        }
        // The address resolved, but the kernel will not make or bind an IPv6 socket.
        if let ioError = error as? IOError {
            return [EAFNOSUPPORT, EPROTONOSUPPORT, EADDRNOTAVAIL].contains(ioError.errnoCode)
        }
        return false
    }
}
