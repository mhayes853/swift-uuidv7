// swift-tools-version: 6.1

import PackageDescription

let package = Package(
  name: "UUIDV7Standalone",
  platforms: [.macOS(.v13)],
  targets: [
    .target(name: "StandaloneUUIDV7"),
    .testTarget(name: "StandaloneUUIDV7Tests", dependencies: ["StandaloneUUIDV7"])
  ],
  swiftLanguageModes: [.v6]
)
