// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "OpenPHEV",
    platforms: [
        .iOS(.v16)
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", from: "7.0.0"),
        .package(url: "https://github.com/kkonteh97/SwiftOBD2", branch: "main"),
    ],
    targets: [
        .target(
            name: "OpenPHEV",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "SwiftOBD2", package: "SwiftOBD2"),
            ],
            path: "OpenPHEV"
        ),
        .testTarget(
            name: "OpenPHEVTests",
            dependencies: ["OpenPHEV"],
            path: "OpenPHEVTests"
        ),
    ]
)
