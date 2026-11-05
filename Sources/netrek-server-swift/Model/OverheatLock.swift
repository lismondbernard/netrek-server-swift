//
//  OverheatLock.swift
//  netrek-server-swift
//
//  Classic's weapon and engine overheat lock (SSS-304). quozl/netrek-server
//  at 43b641f, ntserv/daemon.c, udplayers_palive_cool_weapons and
//  udplayers_palive_cool_engines, run every 0.1 s: once heat is over the
//  ship's limit, each 0.1 s has a 1 in 40 chance of locking, and the lock
//  lasts 100 to 249 tenths of a second (10.0 to 24.9 s) whatever the heat.
//

import Foundation

struct OverheatLock {
    private(set) var tenthsLeft = 0

    /// One 0.1 s step, after this step's cooling. Returns whether the
    /// weapons (or engines) are locked after it.
    mutating func step(heat: Double, limit: Int, roll: (Range<Int>) -> Int) -> Bool {
        if tenthsLeft > 0 {
            tenthsLeft -= 1
            return tenthsLeft > 0
        }
        if heat > Double(limit), roll(0 ..< 40) == 0 {
            tenthsLeft = roll(100 ..< 250)
            return true
        }
        return false
    }
}
