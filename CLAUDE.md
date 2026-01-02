# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is **netrek-server-swift**, a Swift-based Netrek multiplayer space combat game server supporting IPv4/IPv6. It's a rewrite of the classic Netrek server using modern Swift and Swift NIO for async networking.

## Build & Run Commands

```bash
# Build
swift build

# Run locally
swift run netrek-server-swift --directory /tmp/netrek

# Run with options
swift run netrek-server-swift --domain-name example.com --directory /var/netrek --game-style empire

# Run tests (minimal test suite)
swift test
```

**CLI Options:**
- `--domain-name <name>`: FQDN for metaserver display
- `--directory <path>`: Directory for logs and user database (default: /tmp/netrek)
- `--debug`: Enable debug logging (fills disk quickly)
- `--game-style <bronco|empire>`: Game mode (default: empire)

Server runs on port 2592 (hardcoded in `Globals.swift`).

## Architecture

### Core Components

- **Universe.swift**: Central game simulation engine running at 20 Hz. Manages players, planets, projectiles, and game state.
- **Player.swift**: Largest file (~85KB). Contains all player state, ship combat mechanics (lasers, plasma, torpedos), shields, fuel, tractor beams, and statistics.
- **NetrekServerDecoder.swift**: Parses incoming binary packets from clients using Netrek protocol.
- **MakePacket.swift / Packets.swift**: Constructs outgoing binary protocol packets.
- **NetrekChannelHandler.swift**: Swift NIO channel handler for TCP connections.

### Directory Structure

```
Sources/netrek-server-swift/
├── Lifecycle/              # Entry point (main.swift), CLI options, shutdown
├── Communication-Network/  # Packet parsing and creation
├── Communication-NIO/      # Swift NIO handlers
├── Model/                  # Game entities (Player, Planet, Universe)
├── Enumerations/           # Types (Team, ShipType, Rank, etc.)
├── Robots/                 # AI player implementation
├── Protocols/              # Thing protocol for spatial objects
├── Extensions/             # Swift stdlib extensions
└── Filesystem/             # Logging and file I/O
```

### Data Flow

1. Client connects via TCP → `NetrekChannelHandler`
2. Binary packets decoded by `NetrekServerDecoder`
3. Commands processed by `Universe`
4. Game state updated at 20 Hz in `Universe.updateUniverse()`
5. State changes broadcast back to clients via `MakePacket`

### Persistence

- **netrek.database**: User statistics and authentication (JSON)
- **netrek.planets**: Galaxy state between restarts

### Game Modes

- **Empire** (default): 4 teams compete to control 75% of galaxy
- **Bronco**: Classic 2-team mode

## Key Dependencies

- **swift-nio**: Async TCP networking
- **swift-argument-parser**: CLI options
- **swift-log**: Structured logging
- **swift-service-lifecycle**: Graceful startup/shutdown
- **swift-crypto**: Password hashing

## Development Notes

- Game loop runs at 20 updates/second (0.05s per cycle)
- All player state is in-memory; only user stats persist
- Robots auto-spawn to fill empty player slots
- Uses Netrek binary protocol for client communication
- Supports both IPv4 and IPv6 (IPv6 preferred)

## Simulator

Use iPhone 17 Pro simulator with iOS 26.2 for any client testing.
