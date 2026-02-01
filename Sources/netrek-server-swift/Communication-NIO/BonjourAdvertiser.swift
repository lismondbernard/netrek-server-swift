//
//  BonjourAdvertiser.swift
//  netrek-server-swift
//

import Foundation
import Logging
#if canImport(dnssd)
import dnssd
#endif

class BonjourAdvertiser {
    private var serviceRef: DNSServiceRef?
    private let logger = Logger(label: "BonjourAdvertiser")

    func start(port: UInt16) {
        let result = DNSServiceRegister(
            &serviceRef, 0, 0,
            "Netrek",
            "_netrek._tcp",
            nil, nil,
            CFSwapInt16HostToBig(port),
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
}
