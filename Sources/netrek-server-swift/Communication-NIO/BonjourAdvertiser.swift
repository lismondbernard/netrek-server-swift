//
//  BonjourAdvertiser.swift
//  netrek-server-swift
//
//  Advertises the server on the local network as _netrek._tcp, so clients
//  that browse with Bonjour find it without typing an address. Bonjour's
//  dnssd module exists only on Apple platforms; elsewhere (Linux) this is a
//  no-op, so the server still builds and runs there.
//

import Foundation
import Logging
#if canImport(dnssd)
import dnssd
#endif

class BonjourAdvertiser {
    private let logger = Logger(label: "BonjourAdvertiser")

    #if canImport(dnssd)
    private var serviceRef: DNSServiceRef?

    func start(port: UInt16) {
        let result = DNSServiceRegister(
            &serviceRef, 0, 0,
            "Netrek",
            "_netrek._tcp",
            nil, nil,
            port.bigEndian,
            0, nil,
            nil, nil
        )
        if result == kDNSServiceErr_NoError {
            logger.info("Bonjour advertising on port \(port)")
        } else {
            logger.error("Bonjour registration failed: \(result)")
        }
    }

    func stop() {
        if let ref = serviceRef {
            DNSServiceRefDeallocate(ref)
            serviceRef = nil
            logger.info("Bonjour advertising stopped")
        }
    }
    #else
    func start(port: UInt16) {
        logger.info("Bonjour is not available on this platform; not advertising on the local network")
    }

    func stop() {}
    #endif
}
