//
//  main.swift
//  NetrekServer
//
//  Created by Darrell Root on 5/31/20.
//  Copyright © 2020 Darrell Root. All rights reserved.
//

import Foundation
import NIO
import Logging
import Lifecycle
import LifecycleNIOCompat
import Backtrace
#if canImport(Glibc)
import Glibc // `stdout` and `setvbuf` on Linux
#endif

// Write stdout a line at a time. When stdout is not a terminal (under systemd,
// or piped to a file) it is fully buffered, so the start-up lines would only
// reach the journal when the server stops.
setvbuf(stdout, nil, _IOLBF, 0)

print("Initializing server")

let netrekOptions = NetrekOptions.parseOrExit()

LoggingSystem.bootstrap(NetrekLogHandler.init)
// `logger` is declared in Globals.swift. It is created on first use, which is the line below.

let lifecycleConfiguration = ServiceLifecycle.Configuration(logger: logger)

let lifecycle = ServiceLifecycle(configuration: lifecycleConfiguration)

let universe = Universe()

//Backtrace.install()

//first shutdown in file is last executed on macos
lifecycle.registerShutdown(label: "shutdownComplete",.sync(universe.shutdownComplete))

//second to last shutdown executed
lifecycle.registerShutdown(label: "shutdownWarning",.sync(universe.shutdownWarning))

//third to last shutdown executed
lifecycle.registerShutdown(label: "userDatabase", .sync(universe.userDatabase.save))

//lifecycle.registerShutdown(label: "backtrace",.sync(Backtrace.print))
Backtrace.install()

let netrekChannelHandler = NetrekChannelHandler(universe: universe)
let group = MultiThreadedEventLoopGroup(numberOfThreads: 2)
let bootstrap = ServerBootstrap(group: group)
    .serverChannelOption(ChannelOptions.backlog, value: 32)
    .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr),value: 1)
    .childChannelInitializer { channel in
        channel.pipeline.addHandler(netrekChannelHandler).flatMap { v in
        channel.pipeline.addHandler(ByteToMessageHandler(NetrekServerDecoder()))
        }
}
    .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
    .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 16)
    .childChannelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())


lifecycle.registerShutdown(label: "bonjour", .sync({ universe.bonjourAdvertiser?.stop() }))

lifecycle.registerShutdown(label: "eventLoopGroup", .sync(group.syncShutdownGracefully))


lifecycle.start { error in
    // start completion handler.
    // if a startup error occurred you can capture it here
    if let error = error {
        logger.error("failed starting Netrek-server ☠️: \(error)")
    } else {
        logger.info("Netrek-server started successfully 🚀")
    }
}

/// Stops the server with one clear line when it cannot listen.
func stopBecauseUnableToListen(on host: String, port: Int, error: Error) -> Never {
    logger.critical("Unable to listen on \(host) port \(port): \(error). Stopping.")
    exit(1)
}

let netrekChannel: Channel = {
    let port = netrekOptions.port
    if let listenAddress = netrekOptions.listenAddress {
        // Given on the command line: use it as is, and stop if it fails.
        do {
            return try bootstrap.bind(host: listenAddress, port: port).wait()
        } catch {
            stopBecauseUnableToListen(on: listenAddress, port: port, error: error)
        }
    }
    do {
        return try bootstrap.bind(host: ListenAddress.defaultAddress, port: port).wait()
    } catch where ListenAddress.isNoIPv6Error(error) {
        let message = "This host has no IPv6, so listening on \(ListenAddress.defaultAddress) failed (\(error)). Listening on \(ListenAddress.ipv4Fallback) (IPv4 only) instead."
        logger.warning("\(message)")
        print(message)
    } catch {
        stopBecauseUnableToListen(on: ListenAddress.defaultAddress, port: port, error: error)
    }
    do {
        return try bootstrap.bind(host: ListenAddress.ipv4Fallback, port: port).wait()
    } catch {
        stopBecauseUnableToListen(on: ListenAddress.ipv4Fallback, port: port, error: error)
    }
}()

guard let localAddress = netrekChannel.localAddress else {
    logger.critical("Address unable to bind")
    fatalError("Address unable to bind")
}
logger.info("Server started and listening on \(localAddress)")
print("Server started and listening on \(localAddress)")
//lifecycle.wait()

//timer is started in separate thread in universe.swift
print("Starting Run Loop")
RunLoop.current.run()

