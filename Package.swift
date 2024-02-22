// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "Multiplexer",
    platforms: [.iOS(.v12), .macOS(.v12)],
    products: [
        .library(
            name: "Multiplexer",
            targets: ["Multiplexer"]),
    ],
    dependencies: [
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "Multiplexer",
            dependencies: [],
            path: "Multiplexer"
        ),
    ]
)
