# Standalone Smoke Tests

This package compiles a symlink to `Sources/UUIDV7/UUIDV7.swift` without depending on the main package or defining its traits or compilation conditions. It verifies that a copied file enables Foundation support automatically.

Run from the repository root:

```sh
swift test --package-path SmokeTests
swift test --package-path SmokeTests --configuration release
```
