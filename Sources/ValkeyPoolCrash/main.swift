import Foundation
import Logging
import NIOCore
import NIOPosix
import Valkey

@main
enum Entry {
    @concurrent
    static func run() async {
        // Many concurrent commands against a pool with soft limit < hard limit.
        // Every 2 s commands are delayed for longer than the command timeout. The programm crashes shortly after some of the time.

        let port = ProcessInfo.processInfo.environment["VALKEY_PORT"].flatMap(Int.init) ?? 16379
        let address = ValkeyServerAddress.hostname("127.0.0.1", port: port)
        let concurrency = System.coreCount
        let workItems = ProcessInfo.processInfo.environment["WORK_ITEMS"].flatMap(Int.init) ?? 1500
        let workItemDuration = Duration.seconds(1.5) / workItems

        let eventLoopGroup = MultiThreadedEventLoopGroup.singleton
        let client = ValkeyClient(
            address,
            configuration: .init(
                connectionPool: .init(maximumConnectionSoftLimit: System.coreCount / 2, maximumConnectionHardLimit: System.coreCount),
                commandTimeout: .seconds(1),
            ),
            eventLoopGroup: eventLoopGroup,
            logger: Logger(label: "client"),
        )
        let logger = Logger(label: "stall")

        await withThrowingTaskGroup { group in
            group.addTask { await client.run() }

            group.addTask {
                while true {
                    try await Task.sleep(for: .seconds(2))
                    logger.info("blocking event loops for 1.5 s with \(workItems) work items")
                    for eventLoop in eventLoopGroup.makeIterator() {
                        for _ in 0 ..< workItems {
                            eventLoop.execute {
                                let end = ContinuousClock.now + workItemDuration
                                while ContinuousClock.now < end {}
                            }
                        }
                    }
                }
            }

            for worker in 0 ..< concurrency {
                group.addTask {
                    var iteration = 0
                    while true {
                        iteration += 1
                        let key = ValkeyKey("repro-\(worker)-\(iteration)")
                        do {
                            try await client.set(key, value: "value", expiration: .seconds(10))
                            _ = try await client.get(key)
                        } catch {
                            // Expected while the server is stalled: "Connection was closed because it timed out."
                        }
                    }
                }
            }
        }
    }

    static func main() async {
        await run()
    }
}
