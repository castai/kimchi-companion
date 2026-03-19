// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "KimchiCompanion",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "KimchiCompanion",
            path: "Sources/KimchiCompanion"
        )
    ]
)
