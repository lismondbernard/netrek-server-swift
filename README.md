# netrek-server-swift

### I am running an operational "Empire Mode" Swift Netrek server at netrek.networkmom.net (IPv4 + IPv6)
Playing via IPv6 requires an IPv6-capable client, such as my MacOS or iOS clients available for free in the Apple AppStore.

Full game: Thursday 7/30 6PM Pacific.

## This is a new _alpha_ Netrek Server written in Swift!
This does not use any Apple-specific frameworks.  It is developed on MacOS and runs on Linux.

## It supports IPv4 and IPv6!  If you run an IPv6-capable Netrek client (such as the MacOS-Swift or iOS-Swift client), you can play Netrek over IPv6!

# How to build / run:
* git clone https://github.com/darrellroot/netrek-server-swift.git
* cd netrek-server-swift
* swift build
* ./.build/x86_64-unknown-linux-gnu/debug/netrek-server-swift
** See --help for options, such as registering with the metaserver

(alternatively, you can build and run in Xcode on a mac)

## Run on Linux

The server builds and its tests pass on Ubuntu 24.04 (x86_64) with Swift 6.0.3. CI also runs the tests in the `swift:6.0` container.

### Option 1: build on the server

1. Install the Swift toolchain by following https://www.swift.org/install/linux/ for your distribution.
2. Build and run:
```bash
git clone https://github.com/lismondbernard/netrek-server-swift.git
cd netrek-server-swift
swift build -c release
./.build/release/netrek-server-swift --domain-name example.com --directory /var/lib/netrek
```

### Option 2: build once, copy the binary

Build with the Swift runtime linked into the binary, so the server machine does not need the Swift toolchain:
```bash
swift build -c release --static-swift-stdlib
sudo install -m 755 .build/release/netrek-server-swift /usr/local/bin/netrek-server-swift
```
The binary is large (about 95 MB) because it includes the Swift runtime. It still uses the system C libraries (glibc, libstdc++), so build it on the same distribution, or an older one, than the machine that runs it.

### Things to know before you run it

* The server listens on port 2592. By default it listens on `::`, which means every IPv6 address and, on Linux, every IPv4 address too (see below). To choose the address yourself, pass `--listen-address`, for example `--listen-address 0.0.0.0` for IPv4 only.
* If the host has no IPv6 (for example a DigitalOcean droplet created without "Enable IPv6"), listening on `::` can fail. When that happens with the default address, the server prints one line saying so and listens on `0.0.0.0` (IPv4 only) instead. An address you pass with `--listen-address` is used as is: if it fails, the server prints why and stops, with no fallback.
* IPv4 clients reach the `::` socket as long as `net.ipv6.bindv6only` is 0, which is the Linux default (check with `sysctl net.ipv6.bindv6only`). They then show up in the logs as `::ffff:` addresses. If your system sets it to 1, pass `--listen-address 0.0.0.0` or the server will only take IPv6 clients. This has not been tested on a host with IPv6 yet.
* `--directory` must be an existing parent. The server creates the directory it is given, but not its parents. The default is `/tmp/netrek`. For a real server use something that survives a reboot, such as `/var/lib/netrek`.
* The `log.*` files in that directory are deleted and started again every time the server starts.
* The user database (`netrek.database`) is saved when the server gets SIGTERM or SIGINT (for example `systemctl stop`).
* Bonjour is not available on Linux. The server logs that and carries on.

### Run it as a service with systemd (untested)

**This unit file has not been tested.** Check it on your own machine before you rely on it.

Save this as `/etc/systemd/system/netrek.service`:
```ini
[Unit]
Description=Netrek server (netrek-server-swift)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=netrek
Group=netrek
# Creates /var/lib/netrek owned by the netrek user
StateDirectory=netrek
ExecStart=/usr/local/bin/netrek-server-swift --domain-name example.com --directory /var/lib/netrek
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```
Then create the user and start it:
```bash
sudo useradd --system --no-create-home --shell /usr/sbin/nologin netrek
sudo systemctl daemon-reload
sudo systemctl enable --now netrek
journalctl -u netrek -f
```
Replace `example.com` with your server's fully qualified domain name. Leave out `--domain-name` and the server will not report to the metaserver. The game logs go to the `log.*` files in the directory. Only start-up lines and critical errors also reach the journal.

### Firewall

* **TCP 2592 inbound.** Players connect here. Allow it from anywhere you want players to come from.
* **UDP outbound.** With `--domain-name` set, the server sends its status report to `metaserver1.netrek.org` on UDP port 3521. Most firewalls allow outbound traffic already. If yours blocks it, open that one port. Nothing needs to come back in.

For example, with `ufw` (these commands have not been tested here):
```bash
sudo ufw allow 2592/tcp
```
Remember the rule for IPv6 as well as IPv4 if your firewall treats them separately.

## It supports Bronco mode with a command-line-option

## It supports a new Empire mode by default:

* 28-32 total players (starting with 28 robots)
* Four active teams
* Each player is assigned a homeworld randomly
* Each time you spawn, you join the team that owns your homeworld
* As teams gain planets, they gain ships
* Your team wins when you control 75% of the galaxy

### Not currently implemented:

* Robots do not bomb or planet take
* Launching robots when attacking 3rd party planets
* Observers
* Special starbase operations (docking, transwarp, rank requirements, spawn limitations, orbit limitations)
* advanced cloaking visibility (1 per second, hiding far away ships)
* hiding far away ships (PFSEEN flag?)
* UDP sockets
* Short packets
* Coups
* War logic (you are always at war with other teams)

### Local Network Discovery (Bonjour)

On macOS, the server advertises itself on the local network using Bonjour (mDNS/DNS-SD) with the service type `_netrek._tcp` on port 2592. Clients that support Bonjour browsing can discover the server without needing to enter an IP address. On Linux, where Bonjour is not available, the server skips this and runs as before.

To verify the service is advertising:
```bash
dns-sd -B _netrek._tcp
dns-sd -L "Netrek" _netrek._tcp
```

### Supported, but everything needs more testing:

* IPv6 (and IPv4) TCP Sockets!
* Rank logic
* Messages
* Speed / direction
* Laser
* Plasma
* Torpedos
* Refitting ships at homeworld
* Metaserver submissions
* shields
* Remembering statistics between server restarts
* repair
* orbit
* Robots dogfight
* planet lock
* player lock
* bombing
* beaming up/down
* basic cloaking
* Detting friendly and enemy torps
* Tractor/pressor beam
* Logic around t-mode and genocide.
