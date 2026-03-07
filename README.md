# netrek-server-swift

A Swift-based Netrek multiplayer space combat game server supporting IPv4 and IPv6, built with Swift NIO for async networking.

## Features

- IPv4 and IPv6 support
- Empire mode (4 teams, default) and classic Bronco mode (2 teams)
- Bonjour/mDNS local network discovery
- Robot players to fill empty slots
- Persistent user statistics between restarts

## How to build / run

```bash
git clone https://github.com/darrellroot/netrek-server-swift.git
cd netrek-server-swift
swift build
swift run netrek-server-swift --directory /tmp/netrek
```

> **Note:** On macOS with Xcode 26+, the bundled Swift toolchain (5.x via swiftly, etc.) may be too old. Use `xcrun swift build` and `xcrun swift run` instead to use the Xcode toolchain.

See `--help` for options:

```bash
swift run netrek-server-swift --help
```

**CLI options:**
- `--domain-name <name>` — FQDN for metaserver display
- `--directory <path>` — Directory for logs and user database (default: `/tmp/netrek`)
- `--debug` — Enable debug logging
- `--game-style <bronco|empire>` — Game mode (default: `empire`)

The server listens on port **2592**.

Alternatively, you can build and run in Xcode on macOS.

## Empire mode (default)

- 28–32 total players (starting with 28 robots)
- Four active teams
- Each player is assigned a homeworld randomly
- Each time you spawn, you join the team that owns your homeworld
- As teams gain planets, they gain ships
- Your team wins when you control 75% of the galaxy

## Bronco mode

Classic 2-team Netrek. Enable with `--game-style bronco`.

### Not yet implemented

- Robots do not bomb or planet take
- Launching robots when attacking 3rd party planets
- Observers
- Special starbase operations (docking, transwarp, rank requirements, spawn limitations, orbit limitations)
- Advanced cloaking visibility (1 per second, hiding far away ships)
- Hiding far away ships (PFSEEN flag?)
- UDP sockets
- Short packets
- Coups
- War logic (you are always at war with other teams)

### Local Network Discovery (Bonjour)

The server automatically advertises itself on the local network using Bonjour (mDNS/DNS-SD) with the service type `_netrek._tcp` on port 2592. Clients that support Bonjour browsing can discover the server without needing to enter an IP address.

To verify the service is advertising:
```bash
dns-sd -B _netrek._tcp
dns-sd -L "Netrek" _netrek._tcp
```

### Implemented (needs more testing)

- IPv6 and IPv4 TCP sockets
- Rank logic
- Messages
- Speed / direction
- Laser, plasma, torpedos
- Refitting ships at homeworld
- Metaserver submissions
- Shields and repair
- Persistent statistics between server restarts
- Orbit, planet lock, player lock
- Robot dogfighting
- Bombing, beaming up/down
- Basic cloaking
- Detting friendly and enemy torps
- Tractor/pressor beam
- T-mode and genocide logic
