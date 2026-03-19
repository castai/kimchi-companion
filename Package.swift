// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "KimchiCompanion",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-testing.git", from: "0.12.0"),
    ],
    targets: [
        .target(
            name: "KimchiCompanionCore",
            path: "Sources/KimchiCompanionCore"
        ),
        .executableTarget(
            name: "KimchiCompanion",
            dependencies: ["KimchiCompanionCore"],
            path: "Sources/KimchiCompanion"
        ),
        .testTarget(
            name: "KimchiCompanionTests",
            dependencies: [
                "KimchiCompanionCore",
                .product(name: "Testing", package: "swift-testing"),
            ],
            path: "Tests/KimchiCompanionTests"
        ),
    ]
)
