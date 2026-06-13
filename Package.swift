// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Networking",
    platforms: [
        .iOS(.v18), .macOS(.v15), .tvOS(.v18), .watchOS(.v11)
    ],
    products: [
        .library(
            name: "Networking",
            targets: ["Networking"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "Networking",
            dependencies: [],
            path: "Sources"),
        .testTarget(
            name: "NetworkingTests",
            dependencies: ["Networking"],
            path: "Tests",
            resources: [.process("NetworkingTests/Resources")]
        )
    ],
    // tools-version 6.0 is needed for the iOS 18 platform, but keep Swift 5 language mode —
    // a Swift 6 strict-concurrency migration is a separate piece of work.
    swiftLanguageModes: [.v5]
)
