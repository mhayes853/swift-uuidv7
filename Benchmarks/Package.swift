// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "Benchmarks",
  platforms: [.macOS(.v13)],
  dependencies: [
    .package(path: ".."),
    .package(url: "https://github.com/ordo-one/package-benchmark", from: "1.4.0")
  ],
  targets: [
    .executableTarget(
      name: "swift-uuidv7-benchmarks",
      dependencies: [
        .product(name: "UUIDV7", package: "swift-uuidv7"),
        .product(name: "Benchmark", package: "package-benchmark"),
        .product(name: "BenchmarkPlugin", package: "package-benchmark")
      ],
      path: "Benchmarks/swift-uuidv7-benchmarks"
    )
  ]
)
