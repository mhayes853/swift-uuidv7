# Standalone Smoke Tests

This package verifies that `UUIDV7.swift` compiles as a self-contained source file for copy-paste installation. The `StandaloneUUIDV7` target contains only a symlink to `Sources/UUIDV7/UUIDV7.swift`, with no dependency on the main package, package traits, or custom compilation conditions.

The smoke tests exercise UUID generation, ordering, parsing, hashing, Codable interoperability, and automatic Foundation support.

Run from the repository root:

```sh
swift test --package-path SmokeTests
swift test --package-path SmokeTests --configuration release
```
