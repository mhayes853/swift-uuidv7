// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "swift-uuidv7",
  products: [.library(name: "UUIDV7", targets: ["UUIDV7"])],
  traits: [
    .trait(
      name: "SwiftUUIDV7Tagged",
      description: "Adds integrated swift-tagged support to the UUIDV7 type."
    ),
    .trait(
      name: "SwiftUUIDV7StructuredQueries",
      description:
        "Adds swift-structured-queries support and column representations to the UUIDV7 type."
    ),
    .trait(
      name: "SwiftUUIDV7GRDB",
      description: "Conforms UUIDV7 to GRDB's DatabaseValueConvertible protocol."
    )
  ],
  targets: [
    .target(name: "UUIDV7", swiftSettings: [.define("SWIFT_UUIDV7_APPLE_PLATFORMS", .whenApple)]),
    .testTarget(name: "UUIDV7Tests", dependencies: ["UUIDV7"])
  ]
)

extension BuildSettingCondition {
  static let whenApple = Self.when(
    platforms: [.macOS, .iOS, .macCatalyst, .watchOS, .tvOS, .visionOS]
  )
}
