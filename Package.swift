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
      description: """
        Conforms UUIDV7 to GRDB's DatabaseValueConvertible and StatementColumnConvertible \
        protocols, and adds database functions to generate, parse, and extract data from UUIDV7s.
        """
    ),
    .trait(
      name: "SwiftUUIDV7SharingGRDB",
      description: """
        Conforms UUIDV7 to IdentifierStringConvertible to make it compatible with CloudKit sync.

        This trait also enables SwiftUUIDV7GRDB and SwiftUUIDV7StructuredQueries.
        """,
      enabledTraits: ["SwiftUUIDV7GRDB", "SwiftUUIDV7StructuredQueries"]
    ),
    .trait(
      name: "SwiftUUIDV7Dependencies",
      description:
        """
        Adds a dependency value to generate UUIDV7s, and interops the base UUID dependency with \
        UUIDV7 generation.
        """
    )
  ],
  dependencies: [
    .package(url: "https://github.com/groue/GRDB.swift", from: "7.5.0"),
    .package(url: "https://github.com/pointfreeco/swift-tagged", from: "0.10.0"),
    .package(url: "https://github.com/pointfreeco/swift-structured-queries", from: "0.8.1"),
    .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.9.2"),
    .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.0.0"),
    .package(url: "https://github.com/pointfreeco/sharing-grdb-icloud", branch: "cloudkit")
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
        ),
        .product(
          name: "Dependencies",
          package: "swift-dependencies",
          condition: .when(traits: ["SwiftUUIDV7Dependencies"])
        ),
        .product(
          name: "SharingGRDBCore",
          package: "sharing-grdb-icloud",
          condition: .when(traits: ["SwiftUUIDV7SharingGRDB"])
        )
      ]
    ),
    .testTarget(name: "UUIDV7Tests", dependencies: ["UUIDV7"])
  ],
  swiftLanguageModes: [.v6]
)
