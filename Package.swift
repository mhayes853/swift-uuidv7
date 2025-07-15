// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "swift-uuidv7",
  platforms: [.iOS(.v13), .macOS(.v10_15), .tvOS(.v13), .watchOS(.v7), .macCatalyst(.v13)],
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
  dependencies: [
    .package(url: "https://github.com/groue/GRDB.swift", from: "7.5.0"),
    .package(url: "https://github.com/pointfreeco/swift-tagged", from: "0.10.0"),
    .package(url: "https://github.com/pointfreeco/swift-structured-queries", from: "0.8.1")
  ],
  targets: [
    .target(
      name: "UUIDV7",
      dependencies: [
        .product(
          name: "GRDB",
          package: "GRDB.swift",
          condition: .when(traits: ["SwiftUUIDV7GRDB"])
        ),
        .product(
          name: "Tagged",
          package: "swift-tagged",
          condition: .when(traits: ["SwiftUUIDV7Tagged"])
        ),
        .product(
          name: "StructuredQueriesCore",
          package: "swift-structured-queries",
          condition: .when(traits: ["SwiftUUIDV7StructuredQueries"])
        )
      ]
    ),
    .testTarget(name: "UUIDV7Tests", dependencies: ["UUIDV7"])
  ],
  swiftLanguageModes: [.v6]
)
