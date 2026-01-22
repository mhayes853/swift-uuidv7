// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "swift-uuidv7",
    platforms: [.iOS(.v18), .macOS(.v15), .tvOS(.v18), .watchOS(.v11), .macCatalyst(.v18), .visionOS(.v2)],
    products: [
        .library(name: "UUIDV7", targets: ["UUIDV7"]),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-docc-plugin.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "UUIDV7"
        ),
        .testTarget(
            name: "UUIDV7Tests",
            dependencies: ["UUIDV7"],
            swiftSettings: [
                .define(
                    "SWIFT_UUIDV7_EXIT_TESTABLE_PLATFORM",
                    .when(platforms: [.macOS, .linux, .windows])
                )
            ]
        )
    ]
)
