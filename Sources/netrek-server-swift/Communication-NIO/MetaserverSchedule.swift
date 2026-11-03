//
//  MetaserverSchedule.swift
//  netrek-server-swift
//

import Foundation

/// Decides when the metaserver report goes out, the way vanilla's solicit()
/// does (quozl/netrek-server ntserv/solicit.c:317-455):
/// - never sooner than 60 seconds after the last report (solicit.c:318-319,
///   META_MINIMUM_DELAY in include/solicit.h:18). The metaserver delists a
///   server that reports again within 58 seconds (quozl/netrek-metaserver
///   scan.c:1231-1245, MIN_UREAD_TIME in meta.h:34);
/// - after that, as soon as the report differs from the last one sent, for
///   example when a player joins or leaves (solicit.c:444-449);
/// - and at least every 900 seconds even when nothing changed
///   (solicit.c:441-442, META_MAXIMUM_DELAY in include/solicit.h:22).
///
/// Times are seconds on a clock that only goes forward, such as
/// ProcessInfo.systemUptime, so a change of the wall clock cannot stop or
/// speed up the reports. Tests pass their own.
struct MetaserverSchedule {
    static let minimumInterval: TimeInterval = 60
    static let maximumInterval: TimeInterval = 900

    private(set) var lastSent: TimeInterval?
    private(set) var lastReport: String?

    /// Whether to send `report` now.
    func shouldSend(_ report: String, now: TimeInterval) -> Bool {
        guard let lastSent = lastSent else {
            return true // the first report goes out at once
        }
        let elapsed = now - lastSent
        if elapsed < MetaserverSchedule.minimumInterval {
            return false
        }
        if elapsed >= MetaserverSchedule.maximumInterval {
            return true
        }
        return report != lastReport
    }

    /// Records that `report` was sent at `now`.
    mutating func sent(_ report: String, at now: TimeInterval) {
        lastSent = now
        lastReport = report
    }

    /// Returns whether to send `report` now, and if so records it as sent.
    mutating func check(_ report: String, now: TimeInterval) -> Bool {
        guard shouldSend(report, now: now) else { return false }
        sent(report, at: now)
        return true
    }
}
