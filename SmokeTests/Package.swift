// swift-tools-version: 6.1

import PackageDescription

let package = Package(
  name: "UUIDV7Standalone",
  platforms: [.macOS(.v13)],
  targets: [
    .target(name: "UUIDV7"),
    .testTarget(name: "UUIDV7Tests", dependencies: ["UUIDV7"])
  ],
  swiftLanguageModes: [.v6]
)
