// swift-tools-version: 6.2
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
    swiftLanguageModes: [.v6]
)
