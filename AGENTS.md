# Swift UUIDV7
You are currently working with Swift code within a Swift package. Below are common anti-patterns that agents tend to follow, and what you should do instead. Make sure to generate code in correspondence with examples listed as GOOD or OK, and avoid generating code listed as a BAD example.

## Basics
### Always Use Type Names For Calling Initializers
```swift
struct Foo {}

// GOOD
let foo = Foo()

// BAD
let foo: Foo = .init()
```

### Avoid Explicit Collection Types For Empty Collections
``` swift
// GOOD
let arr = [UInt8]()
let dict = [String: Int]()

// BAD
let arr: [UInt8] = []
let dict: [String: Int] = [:]
```

### Prefer Using `self` When Accessing Member Variables And Methods
```swift
struct Item {
  let property: String
}

// GOOD
extension Item {
  var propertyCount: Int {
    self.property.count
  }
}

// BAD
extension Item {
  var propertyCount: Int {
    property.count
  }
}
```

### Prefer Using `Self` When Accessing static Variables And Methods
```swift
struct Item {
  static let property = "..."
}

// GOOD
extension Item {
  static var propertyCount: Int {
    Self.property.count
  }
}

// BAD
extension Item {
  static var propertyCount: Int {
    property.count
  }
}

extension Item {
  static var propertyCount: Int {
    self.property.count
  }
}
```

### Avoid Delayed Nested Local Property Initializations
Avoid nesting initial assignments inside nested blocks such as in conditional and switch statements.
```swift
// GOOD
func foo() {
  let property = bar()
  // ...
}

func bar() -> Value {
  if someCondition {
    currentValue
  } else {
    previousValue
  }
}

// BAD
func foo() {
  let property: Value
  if someCondition {
    property = currentValue
  } else {
    property = previousValue
  }

  // ...
}
```

### Prefer No Return Keyword For One Line Conditional Expressions
```swift
// GOOD
func value() -> Value {
  switch statement {
  case 1: 1
  case 4: 16
  default: 64
  }
}

func value() -> Value {
  if statement == 1 {
    1
  } else if statement == 4 {
    16
  } else {
    64
  }
}

// BAD
func value() -> Value {
  switch statement {
  case 1: return 1
  case 4: return 16
  default: return 64
  }
}

func value() -> Value {
  if statement == 1 {
    return 1
  } else if statement == 4 {
    return 16
  } else {
    return 64
  }
}
```

### Avoid `private static` Helper Methods For Instance Methods
```swift
struct Value {}

// GOOD
extension Value {
  func foo() {
    // ...
    self.bar()
    // ...
  }

  private func bar() {
    // ...
  }
}

// BAD
extension Value {
  func foo() {
    // ...
    Self.bar()
    // ...
  }

  private static func bar() {
    // ...
  }
}
```

### Prefer Sequence Algorithms Over Raw Loops
```swift
// GOOD
let transformedItems = items.compactMap {
  guard $0.count > 0 else { return nil }
  return TransformedItem($0) 
}

let filteredItems = items.filter { $0.count > 0 }

// BAD
var transformedItems = [TransformedItem]()
for item in items {
  guard item.count > 0 else { continue }
  transformedItems.append(TransformedItem(item))
}

var filteredItems = [Item]()
for item in items {
  guard item.count > 0 else { continue }
  filteredItems.append(item)
}
```

### Prefer Optional Algorithms Over Long Drawn Out Unwrap Checks
```swift
struct Item {
  let name: String?
}

// GOOD
func updatedName(item: Item) -> String? {
  item.name.map { $0 + " Updated" }
}

// BAD
func updatedName(item: Item) -> String? {
  guard let name = item.name else { return nil }
  return name + " Updated" 
}
```

### Always Make Trivial Structs Hashable and Sendable
```swift
// GOOD
struct Item: Hashable, Sendable {
  let name: String
  let quantity: Int
}

// BAD
struct Item {
  let name: String
  let quantity: Int
}
```

### Prefer `self.init` Instead Of Property Assignments In Initializers
```swift
struct Item: Hashable, Sendable {
  let name: String
  let quantity: Int
}

// GOOD
extension Item {
  init(name: String) {
    self.init(name: name, quantity: 0)
  }
}

// BAD
extension Item {
  init(name: String) {
    self.name = name
    self.quantity = 0
  }
}
```

## Concurrency
### Avoid `@unchecked Sendable` Without Justification
Avoid conforming to `@unchecked Sendable`, and try to always make a type conform to Sendable proper instead. If you must conform to `@unchecked Sendable`, then make sure to leave a comment explaining why it is safe to do so.
```swift
// GOOD
final class Item: Sendable {
  let count = Mutex(0)
  // ...
}

// OK (but not always ideal, avoid if possible)
final class Item: @unchecked Sendable {
  // NB: @unchecked Sendable is safe because we use a lock.
  private let lock = NSLock()
  var count = 0

  // ...
}

// BAD
final class Item: @unchecked Sendable {
  var count = 0

  // ...
}
```

### Avoid `Task.detached` At All Costs
`Task.detached` is rarely useful, and can almost always be expressed in simpler ways. Prefer traditional `Task` initializations instead.
```swift
// GOOD
Task { await work() }

// BAD
Task.detached { await work() }
```

### Prefer `sending` And Region Based Isolation Over Making A Type Sendable If Possible
If the `sending` keyword and `nonisolated(nonsending)` directive can be used to solve a concurrency error related to a non-Sendable value, then use it instead of conforming the type to Sendable.
```swift
final class NonSendable {}

// GOOD
func work(value: sending NonSendable) {
  Task { await value.workAsync() }
}

extension NonSendable {
  nonisolated(nonsending) func workAsync() async {
    // ...
  }
}

// BAD
extension NonSendable: Sendable {
  func workAsync() async {
    // ...
  }
}

func work(value: NonSendable) {
  Task { await value.workAsync() }
}
```

### Non-Sendable Core, Sendable Shell
If you need to conform an existing non-Sendable type to Sendable, consider creating a small wrapper that conforms to Sendable, and that wraps the non-Sendable core. this way, you push the need for Sendable away as far as possible. Generally, follow the principles in [this](https://whypeople.xyz/non-sendable-core-sendable-shell) article.

## Testing
### Prefer Swift Testing
Use Swift Testing by default. You should only fallback to XCTest if you must write a test that request an `XCTestExpectation`.
```swift
// GOOD
import Testing

@Test
func `My Work Does Something`() {
  // ...
}

// OK (Only if you need to use XCTestExpectation)
import XCTest

final class MyTestSuite {
  func testMyWorkDoesSomething() async {
    let expectation = self.expectation(description: "Finishes")
    // ...
  }
}

// BAD
import XCTest

final class MyTestSuite {
  func testMyWorkDoesSomething() {
    // ...
  }
}
```

### Prefer `expectNoDifference` From CustomDump Over `#expect`
If `CustomDump` is added as a dependency, prefer `expectNoDifference` instead of the `#expect` macro from Swift testing.
```swift
// GOOD
import CustomDump

@Test
func `Matches`() {
  let v1 = NyEquatableValue(value: 10)
  let v2 = MyEquatableValue(value: 10)
  expectNoDifference(v1, v2)
}

// BAD
@Test
func `Matches`() {
  let v1 = NyEquatableValue(value: 10)
  let v2 = MyEquatableValue(value: 10)
  #expect(v1 == v2)
}
```

### Use A Captial Letter For the First Letter Of Each Word In The Test Name
```swift
// GOOD
@Test
func `This Is A Test Of Something`() {
  // ...
}

// BAD
@Test
func `this is a test of something`() {
  // ...
}
```

### Use `#expect(throws:)` For Detecting Errors In Swift Testing
```swift
// GOOD
@Test
func `Work Throws`() {
  #expect(throws: WorkError.self) {
    try work()
  }
}

// BAD
@Test
func `Work Throws`() {
  do {
    try work()
    Issue.record("Expected error but none thrown.")
  } catch {
    expectNoDifference(error is WorkError, true)
  }
}
```

### Use `Subject tests` For Naming Test Suites
```swift
// GOOD
@Suite
struct `MyValue tests` {
  // ...
}

// BAD
struct MyValueTests {
  // ...
}
```

## Building/Compiling
### Use `—disable-experimental-prebuilts` To Handle Build Errors In Packages With Macros
If you run into a build error in a package with at least 1 macro target that states that the “SwiftCompilerPlugin” cannot be found, do the following:
- Fully delete the `.build` directory (`rm -drf .build`).
- Rerun `swift build --build-tests --disable-experimental-prebuilts`.
- Then proceed with the build/test/run command you were attempting before.

You should also run this flow if you ever run `swift package clean`.
