# Swift UUIDV7

[![CI](https://github.com/mhayes853/swift-uuidv7/actions/workflows/ci.yml/badge.svg)](https://github.com/mhayes853/swift-uuidv7/actions/workflows/ci.yml)

An RFC 9562 compliant UUIDV7 data type with cross-platform support and support for popular libraries.

```swift
import UUIDV7
import Foundation

let id = UUIDV7()
let id2 = UUID()

// 0198143f-f09c-772d-a29a-42b1ca62e784
print(id.uuidString)

// d486cf16-e095-4ad0-a871-492623cd654c
print(id2.uuidString)
```

## Overview
Swift’s `UUID` type in Foundation represents any kind of UUID, but most commonly it is used as a version 4 UUID. Version 4 UUIDs are generated entirely based on random data which is fine, but runs into an ordinality problem as a result of the data being entirely random. For instance, how do you sort a collection by a UUID? Is that even a reasonable thing to do?

`UUIDV7` on the other hand, embeds a timestamp in its most significant 48 bits which enables ordinality across ids. Therefore, you can sort a collection by referring to a `UUIDV7` as a sort key.

One of the most common use cases for such a need is as a primary key in databases. UUIDs make great primary keys because of their randomness, but the complete randomness of v4 UUIDs are poor for index locality. Since `UUIDV7` uses a timestamp alongside random data, it has better index locality whilst still maintaining similar levels of randomness to v4 UUIDs.

### Why a separate type?
`UUIDV7` holds a few extra properties that cannot be guaranteed in a typical Foundation UUID, most notably the timestamp and the notion of ordinality.

On the timestamp, one could easily make an extension property on a Foundation `UUID` that interprets the first 48-bits as a timestamp, but this comes as the expense of the caller needing to be aware that such a property only holds true for UUID versions that use a timestamp in the first place. Given that most Foundation UUID instances are v4 UUIDs, this could easily be misused.

On ordinality, Foundation’s `UUID` conforms to Comparable, but such a conformance falls into the same pitfalls as the timestamp case due to the lack of ordinality in typical v4 UUIDs. Additionally, Foundation UUID’s Comparable conformance is limited to specific platform versions (iOS 17+, macOS 14+, watchOS 10+, tvOS 17+).

`UUIDV7` conforms to RawRepresentable and uses a Foundation `UUID` as its raw value. Additionally, it also implements dynamic member lookup on Foundation UUID’s properties, so you can access all the typical properties (and any that are added in the future) just as you would on a typical `UUID`.

### Sub-millisecond Monotonicity
RFC 9562 does not require subsequent `UUIDV7` generations to have a notion of being monotonically increasing. In other words, this property is not a strict requirement.
```swift
import UUIDV7

let id1 = UUIDV7()
let id2 = UUIDV7()
assert(id2 > id1) // Not required to be true by RFC 9562.
```

However, the RFC also outlines that one may replace the 12 random bits from the `rand_a` field with data that holds, and the implementation is this library uses those bits to _uphold the property of monotonically increasing generations_. This is even the case when the user changes their system clock backwards far into the past. In other words, this property is guaranteed 100% of the time by the library.
```swift
import UUIDV7

let id1 = UUIDV7()
let id2 = UUIDV7()
assert(id2 > id1) // True 100% of the time in this library.
```

If you do not want to maintain the property of monotonically increasing generations, you can pass the current date in the initializer instead.
```swift
import UUIDV7

let id1 = UUIDV7(.now)
let id2 = UUIDV7(.now)
assert(id2 > id1) // No longer true 100% of the time.
```

## Library Integrations
The library ships with UUID v7 support to popular libraries in the ecosystem, each behind a package trait.

- [Tagged](https://github.com/pointfreeco/swift-tagged)
  - **Trait:** `SwiftUUIDV7Tagged`
  - Adds convenience initializers to `Tagged` that support `UUIDV7` generations.
- [GRDB](https://github.com/groue/GRDB.swift)
  - **Trait:** `SwiftUUIDV7GRDB`
  - Adds `DatabaseValueConvertible` and `StatementColumnConvertible` conformances to `UUIDV7`.
  - Adds `DatabaseFunction` instances for generating, parsing, and extracting properties from `UUIDV7`.
- [StructuredQueries](https://github.com/pointfreeco/swift-structured-queries)
  - **Trait:** `SwiftUUIDV7StructuredQueries`
  - Adds a `QueryBindable` conformance to `UUIDV7`.
  - Adds `UUIDV7.BytesRepresentation` and `UUIDV7.UppercaseRepresentation` column representations of `UUIDV7`.
- [Dependencies](https://github.com/pointfreeco/swift-dependencies)
  - **Trait:** `SwiftUUIDV7Dependencies`
  - Adds a `UUIDV7Generator` dependency.
  - Adds an initializer to `UUIDGenerator` that generates `UUIDV7` instances under the hood.

Additionally, `UUIDV7` conforms to `EntityIdentifierConvertible` from AppIntents, which is available without a need to specify a trait when building for Apple platforms.

## Installation
You can add Swift UUIDV7 to an Xcode project by adding it to your project as a package.

> [https://github.com/mhayes853/swift-uuidv7](https://github.com/mhayes853/swift-uuidv7)

If you want to use Swift UUIDV7 in a [SwiftPM](https://swift.org/package-manager/) project, it’s as simple as adding it to your `Package.swift`:

```swift
dependencies: [
  .package(
    url: "https://github.com/mhayes853/swift-uuidv7",
    from: "0.1.0",
    // You can omit the traits if you don't need any of them.
    traits: ["SwiftUUIDV7GRDB"]
  ),
]
```

## License
This library is licensed under an MIT License. See [LICENSE](https://github.com/mhayes853/swift-uuidv7/blob/main/LICENSE) for details.
