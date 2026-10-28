// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "ValkeyPoolCrash",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/valkey-io/valkey-swift.git", exact: "1.5.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.93.0"),
    ],
    targets: [
        .executableTarget(
            name: "ValkeyPoolCrash",
            dependencies: [
                .product(name: "Valkey", package: "valkey-swift"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
            ]
        )
    ]
)
