#if canImport(WinSDK)
  import WinSDK
#elseif canImport(Android)
  import Android
#elseif canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#elseif canImport(Musl)
  import Musl
#elseif canImport(Bionic)
  import Bionic
#elseif os(WASI)
  import WASILibc
#elseif arch(wasm32)
#else
  #error("Unsupported platform")
#endif

#if !SWIFT_UUIDV7_PACKAGE_BUILD || SwiftUUIDV7Foundation
  #if canImport(FoundationEssentials)
    import FoundationEssentials
  #elseif canImport(Foundation)
    import Foundation
  #endif
#endif

#if compiler(>=6.2.3) && hasFeature(Lifetimes) && hasFeature(AddressableTypes) && hasFeature(BuiltinModule)
  import Builtin
#endif

#if canImport(CUUIDV7) && (arch(arm64) || arch(x86_64)) && !os(Windows)
  internal import CUUIDV7
#endif

#if (!SWIFT_UUIDV7_PACKAGE_BUILD || SwiftUUIDV7Foundation) && (canImport(FoundationEssentials) || canImport(Foundation))
  public typealias UUIDBytes = uuid_t
#else
  public typealias UUIDBytes = (
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
  )

  public typealias TimeInterval = Double
#endif

/// A variant of UUID as defined by RFC 9562.
public enum UUIDVariant: Hashable, Sendable {
  /// Reserved by the NCS for backward compatibility.
  case ncs

  /// The default variant as defined by RFC 9562.
  case rfc9562

  /// Reserved by Microsoft for backward compatibility.
  case microsoft

  /// Reserved for future use.
  case future

  /// The variant of the specified ``UUIDBytes`` as defined by RFC 9562.
  public init(uuid: UUIDBytes) {
    let x = uuid.8
    if x & 0x80 == 0x00 {
      self = .ncs
    } else if x & 0xC0 == 0x80 {
      self = .rfc9562
    } else if x & 0xE0 == 0xC0 {
      self = .microsoft
    } else {
      self = .future
    }
  }
}

// MARK: - UUIDV7

#if (!SWIFT_UUIDV7_PACKAGE_BUILD || SwiftUUIDV7Foundation) && (canImport(FoundationEssentials) || canImport(Foundation))
  @dynamicMemberLookup
#endif
#if compiler(>=6.2.3) && hasFeature(AddressableTypes)
  @_addressableForDependencies
#endif
public struct UUIDV7 {
  /// The raw ``UUIDBytes`` of this UUID.
  public private(set) var uuid: UUIDBytes

  /// Creates a UUID from the specified bytes.
  ///
  /// The bytes must indicate that the UUID is a version 7 UUID.
  ///
  /// - Parameter bytes: The bytes to use for the UUID.
  public init?(uuid: UUIDBytes) {
    let isRFC9562Variant = UUIDVariant(uuid: uuid) == .rfc9562
    let isVersion7 = uuid.6 >> 4 == 0x7
    guard isVersion7 && isRFC9562Variant else { return nil }
    self.uuid = uuid
  }
}

// MARK: - Date

extension UUIDV7 {
  /// The timestamp embedded in this UUID.
  public var timeIntervalSince1970: TimeInterval {
    Self._timeIntervalSince1970(self.uuid)
  }

  package static func _timeIntervalSince1970(_ uuid: UUIDBytes) -> TimeInterval {
    let t1 = UInt64(uuid.0) << 40
    let t2 = UInt64(uuid.1) << 32
    let t3 = UInt64(uuid.2) << 24
    let t4 = UInt64(uuid.3) << 16
    let t5 = UInt64(uuid.4) << 8
    let t6 = UInt64(uuid.5)
    return TimeInterval(t1 | t2 | t3 | t4 | t5 | t6) / 1000
  }
}

#if (!SWIFT_UUIDV7_PACKAGE_BUILD || SwiftUUIDV7Foundation) && (canImport(FoundationEssentials) || canImport(Foundation))
  extension UUIDV7 {
    /// The date embedded in this UUID.
    public var date: Date {
      Date(timeIntervalSince1970: self.timeIntervalSince1970)
    }
  }
#endif

// MARK: - Monotonically Increasing Initializer

extension UUIDV7 {
  /// Creates a UUID with the current date as the timestamp.
  ///
  /// This initializer will always generate monotonically increasing UUIDs. This means that this property:
  /// ```swift
  /// let u1 = UUIDV7()
  /// let u2 = UUIDV7()
  /// assert(u2 > u1) // Always true
  /// ```
  /// Is always true, even when the device's system clock is manually moved backwards.
  ///
  /// The 12 random bits that comprise of the `rand_a` field from RFC 9562 are replaced by a 12 bit
  /// counter as outlined by section 6.2 of the RFC.
  public init() {
    self.init(_systemNow: Self._platformTimeIntervalSince1970())
  }

  /// Creates a UUID with the current date offset by the specified duration as the timestamp.
  ///
  /// The offset is applied after the monotonic timestamp is computed. Therefore, UUIDs created
  /// with the same offset will always be monotonically increasing, and the offset never affects
  /// the timestamps of UUIDs created with other offsets.
  ///
  /// - Parameter offset: A duration to add to the current date.
  public init(offset: Duration) {
    self.init(_systemNow: Self._platformTimeIntervalSince1970(), offset: offset)
  }

  /// Creates a UUID with the current date as the timestamp, using the specified random number
  /// generator for the random data.
  ///
  /// Like ``init()``, this initializer will always generate monotonically increasing UUIDs. The
  /// 12 bit `rand_a` field holds a counter, and the remaining 62 random bits are produced by
  /// `generator`.
  ///
  /// The offset is applied after the monotonic timestamp is computed. Therefore, UUIDs created
  /// with the same offset will always be monotonically increasing, and the offset never affects
  /// the timestamps of UUIDs created with other offsets.
  ///
  /// - Parameters:
  ///   - generator: The random number generator to use when creating the random data.
  ///   - offset: A duration to add to the current date.
  public init(using generator: inout some RandomNumberGenerator, offset: Duration = .zero) {
    let bytes = Self.randomBytes(using: &generator)
    self.init(Self._platformTimeIntervalSince1970(), offset.uuidV7Milliseconds, bytes)
  }

  package init(_systemNow timeInterval: TimeInterval) {
    self.init(timeInterval, 0)
  }

  package init(_systemNow timeInterval: TimeInterval, offset: Duration) {
    self.init(timeInterval, offset.uuidV7Milliseconds)
  }

  package init(_clampingOffset offset: Duration) {
    self.init(
      Self._platformTimeIntervalSince1970(),
      offset.uuidV7Milliseconds,
      clampsToEpoch: true
    )
  }

  package init(
    _clampingOffset offset: Duration,
    using generator: inout some RandomNumberGenerator
  ) {
    let bytes = Self.randomBytes(using: &generator)
    self.init(
      Self._platformTimeIntervalSince1970(),
      offset.uuidV7Milliseconds,
      bytes,
      clampsToEpoch: true
    )
  }

  private init(
    _ systemTimeInterval: TimeInterval,
    _ offsetMillis: Int64,
    clampsToEpoch: Bool = false
  ) {
    let (millis, sequence, bytes) = GenerationState.shared.withLock { state in
      let (millis, sequence) = state.monotonicity.nextMillisWithSequence(
        timeIntervalSince1970: systemTimeInterval
      )
      return (millis, sequence, state.random.next())
    }
    self.init(millis, sequence, offsetMillis, bytes, clampsToEpoch: clampsToEpoch)
  }

  private init(
    _ systemTimeInterval: TimeInterval,
    _ offsetMillis: Int64,
    _ bytes: UUIDBytes,
    clampsToEpoch: Bool = false
  ) {
    let (millis, sequence) = GenerationState.shared.withLock {
      $0.monotonicity.nextMillisWithSequence(timeIntervalSince1970: systemTimeInterval)
    }
    self.init(millis, sequence, offsetMillis, bytes, clampsToEpoch: clampsToEpoch)
  }

  private init(
    _ millis: UInt64,
    _ sequence: UInt16,
    _ offsetMillis: Int64,
    _ bytes: UUIDBytes,
    clampsToEpoch: Bool
  ) {
    let timestampMillis = Int64(millis) + offsetMillis
    precondition(
      clampsToEpoch || timestampMillis >= 0,
      _negativeTimeStampMessage(TimeInterval(timestampMillis) / 1000)
    )
    var bytes = bytes
    withUnsafePointer(to: sequence.bigEndian) { ptr in
      ptr.withMemoryRebound(to: (UInt8, UInt8).self, capacity: 1) {
        bytes.6 = $0.pointee.0
        bytes.7 = $0.pointee.1
      }
    }
    self.init(UInt64(Swift.max(0, timestampMillis)), &bytes)
  }
}

#if (!SWIFT_UUIDV7_PACKAGE_BUILD || SwiftUUIDV7Foundation) && (canImport(FoundationEssentials) || canImport(Foundation))
  extension UUIDV7 {
    package init(_systemNow: Date) {
      self.init(_systemNow: _systemNow.timeIntervalSince1970)
    }
  }
#endif

// MARK: - Time Initializers

extension UUIDV7 {
  /// Creates a UUID with the specified unix epoch.
  ///
  /// This initializer does not implement sub-millisecond monotonicity, use ``init()`` instead if
  /// sub-millisecond monotonicity is needed.
  ///
  /// - Parameter timeInterval: The `TimeInterval` since 00:00:00 UTC on 1 January 1970.
  public init(timeIntervalSince1970 timeInterval: TimeInterval) {
    var bytes = GenerationState.shared.withLock { $0.random.next() }
    self.init(timeInterval, &bytes)
  }

  /// Creates a UUID with the specified unix epoch offset by the specified duration.
  ///
  /// This initializer does not implement sub-millisecond monotonicity, use ``init(offset:)``
  /// instead if sub-millisecond monotonicity is needed.
  ///
  /// - Parameters:
  ///   - timeInterval: The `TimeInterval` since 00:00:00 UTC on 1 January 1970.
  ///   - offset: A duration to add to `timeInterval`.
  public init(timeIntervalSince1970 timeInterval: TimeInterval, offset: Duration) {
    self.init(timeIntervalSince1970: timeInterval + offset.uuidV7TimeInterval)
  }

  /// Creates a UUID with the specified unix epoch, using the specified random number generator
  /// for the random data.
  ///
  /// All 74 random bits of this UUID are produced by `generator`. Therefore, 2 UUIDs with the same
  /// unix epoch created from identically seeded generators will be equal.
  ///
  /// This initializer does not implement sub-millisecond monotonicity, use
  /// ``init(using:offset:)`` instead if sub-millisecond monotonicity is needed.
  ///
  /// - Parameters:
  ///   - timeInterval: The `TimeInterval` since 00:00:00 UTC on 1 January 1970.
  ///   - generator: The random number generator to use when creating the random data.
  ///   - offset: A duration to add to `timeInterval`.
  public init(
    timeIntervalSince1970 timeInterval: TimeInterval,
    using generator: inout some RandomNumberGenerator,
    offset: Duration = .zero
  ) {
    var bytes = Self.randomBytes(using: &generator)
    self.init(timeInterval + offset.uuidV7TimeInterval, &bytes)
  }

  /// Creates a UUID with the specified unix expoch and an integer that acts as the random data.
  ///
  /// This initializer is convenient for creating deterministic UUIDs. 2 UUIDs with the same
  /// unix epoch and integer creating using this initializer will be equal.
  ///
  /// This initializer does not implement sub-millisecond monotonicity, use ``init()`` instead if
  /// sub-millisecond monotonicity is needed.
  ///
  /// - Parameters:
  ///   - timeInterval: The `TimeInterval` since 00:00:00 UTC on 1 January 1970.
  ///   - integer: An integer to use in the random data part of this UUID.
  public init(timeIntervalSince1970 timeInterval: TimeInterval, _ integer: UInt32) {
    var bytes = Self.nilUUIDBytes
    let byteCount = Int(ceil(Double(integer.bitWidth - integer.leadingZeroBitCount) / 8.0))
    withUnsafeMutablePointer(to: &bytes) { ptr in
      withUnsafePointer(to: integer) { integerPtr in
        UnsafeMutableRawPointer(ptr).advanced(by: MemoryLayout<UUIDBytes>.size - byteCount)
          .copyMemory(from: integerPtr, byteCount: byteCount)
      }
    }
    self.init(timeInterval, &bytes)
  }

  private init(_ timeInterval: TimeInterval, _ bytes: inout UUIDBytes) {
    precondition(timeInterval >= 0, _negativeTimeStampMessage(timeInterval))
    self.init(UInt64(timeInterval * 1000), &bytes)
  }

  private init(_ timeMillis: UInt64, _ bytes: inout UUIDBytes) {
    withUnsafePointer(to: timeMillis.bigEndian) { ptr in
      let ptr = UnsafeRawPointer(ptr).advanced(by: 2)
        .assumingMemoryBound(to: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8).self)
      bytes.0 = ptr.pointee.0
      bytes.1 = ptr.pointee.1
      bytes.2 = ptr.pointee.2
      bytes.3 = ptr.pointee.3
      bytes.4 = ptr.pointee.4
      bytes.5 = ptr.pointee.5
    }
    bytes.6 = (bytes.6 & 0x0F) | 0x70
    bytes.8 = (bytes.8 & 0x3F) | 0x80
    self.uuid = bytes
  }
}

// MARK: - Convenience Initializers

#if (!SWIFT_UUIDV7_PACKAGE_BUILD || SwiftUUIDV7Foundation) && (canImport(FoundationEssentials) || canImport(Foundation))
  extension UUIDV7 {
    /// Creates a UUID with the specified `Date`.
    ///
    /// This initializer does not implement sub-millisecond monotonicity, use ``init()`` instead if
    /// sub-millisecond monotonicity is needed.
    ///
    /// - Parameter date: The `Date` to embed in this UUID.
    public init(_ date: Date) {
      self.init(timeIntervalSince1970: date.timeIntervalSince1970)
    }

    /// Creates a UUID with the specified `Date` and an integer that acts as the random data.
    ///
    /// This initializer is convenient for creating deterministic UUIDs. 2 UUIDs with the same date
    /// and integer creating using this initializer will be equal.
    ///
    /// This initializer does not implement sub-millisecond monotonicity, use ``init()`` instead if
    /// sub-millisecond monotonicity is needed.
    ///
    /// - Parameters:
    ///   - date: The `Date` to embed in this UUID.
    ///   - integer: An integer to use in the random data part of this UUID.
    public init(_ date: Date, _ integer: UInt32) {
      self.init(timeIntervalSince1970: date.timeIntervalSince1970, integer)
    }

    /// Creates a UUID with the specified `Date` offset by the specified duration.
    ///
    /// This initializer does not implement sub-millisecond monotonicity, use ``init(offset:)``
    /// instead if sub-millisecond monotonicity is needed.
    ///
    /// - Parameters:
    ///   - date: The `Date` to embed in this UUID.
    ///   - offset: A duration to add to `date`.
    public init(_ date: Date, offset: Duration) {
      self.init(timeIntervalSince1970: date.timeIntervalSince1970, offset: offset)
    }

    /// Creates a UUID with the specified `Date`, using the specified random number generator for
    /// the random data.
    ///
    /// All 74 random bits of this UUID are produced by `generator`. Therefore, 2 UUIDs with the
    /// same date created from identically seeded generators will be equal.
    ///
    /// This initializer does not implement sub-millisecond monotonicity, use
    /// ``init(using:offset:)`` instead if sub-millisecond monotonicity is needed.
    ///
    /// - Parameters:
    ///   - date: The `Date` to embed in this UUID.
    ///   - generator: The random number generator to use when creating the random data.
    ///   - offset: A duration to add to `date`.
    public init(
      _ date: Date,
      using generator: inout some RandomNumberGenerator,
      offset: Duration = .zero
    ) {
      self.init(
        timeIntervalSince1970: date.timeIntervalSince1970,
        using: &generator,
        offset: offset
      )
    }
  }
#endif

package func _negativeTimeStampMessage(_ timeInterval: TimeInterval) -> String {
  #if (!SWIFT_UUIDV7_PACKAGE_BUILD || SwiftUUIDV7Foundation) && (canImport(FoundationEssentials) || canImport(Foundation))
    let timeInterval = Date(timeIntervalSince1970: timeInterval)
  #endif
  return
    "Cannot create a UUIDV7 with a timestamp before January 1, 1970. (Received: \(timeInterval))"
}

// MARK: - Now

extension UUIDV7 {
  /// Returns a ``UUIDV7`` initialized to the current date and time.
  public static var now: Self { Self() }
}

// MARK: - Min And Max

extension UUIDV7 {
  /// The smallest possible ``UUIDV7``, “00000000-0000-7000-8000-000000000000”.
  ///
  /// Unlike the nil UUID defined by RFC 9562, this UUID has its version and variant bits set, and
  /// can be used as a lower bound when querying a range of UUIDs.
  public static let min = UUIDV7(
    uuid: (0, 0, 0, 0, 0, 0, 0x70, 0, 0x80, 0, 0, 0, 0, 0, 0, 0)
  )!

  /// The largest possible ``UUIDV7``, “FFFFFFFF-FFFF-7FFF-BFFF-FFFFFFFFFFFF”.
  ///
  /// Unlike the max UUID defined by RFC 9562, this UUID has its version and variant bits set, and
  /// can be used as an upper bound when querying a range of UUIDs.
  public static let max = UUIDV7(
    uuid: (
      0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x7F, 0xFF,
      0xBF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF
    )
  )!
}

// MARK: - Version And Variant

extension UUIDV7 {
  /// The version number of this UUID as defined by RFC 9562, which is always 7.
  public var version: Int {
    7
  }

  /// The variant of this UUID as defined by RFC 9562, which is always ``UUIDVariant/rfc9562``.
  public var variant: UUIDVariant {
    .rfc9562
  }
}

// MARK: - Basic Initializers

#if (!SWIFT_UUIDV7_PACKAGE_BUILD || SwiftUUIDV7Foundation) && (canImport(FoundationEssentials) || canImport(Foundation))
  extension UUIDV7 {
    /// Attempts to create a ``UUIDV7`` from a Foundation UUID.
    ///
    /// The Foundation UUID must be compliant with RFC 9562 UUID Version 7.
    ///
    /// - Parameter uuid: A Foundation UUID.
    public init?(_ uuid: UUID) {
      self.init(rawValue: uuid)
    }
  }
#endif

// MARK: - Span Initializers

#if compiler(>=6.2.3)
  extension UUIDV7 {
    /// Attempts to create a ``UUIDV7`` by copying exactly 16 bytes from a `RawSpan`.
    ///
    /// The bytes must be compliant with RFC 9562 UUID Version 7.
    ///
    /// - Precondition: `bytes.byteCount` must be exactly 16.
    /// - Parameter bytes: The bytes to copy.
    public init?(copying bytes: RawSpan) {
      self.init(uuid: Self._uuidBytes(copying: bytes))
    }

    /// Attempts to create a ``UUIDV7`` by filling its 16 bytes using a closure that writes into an
    /// `OutputRawSpan`.
    ///
    /// The written bytes must be compliant with RFC 9562 UUID Version 7.
    ///
    /// - Precondition: `initializer` must write exactly 16 bytes.
    /// - Parameter initializer: A closure that writes the bytes of the UUID.
    public init?<E: Error>(
      initializingWith initializer: (inout OutputRawSpan) throws(E) -> Void
    ) throws(E) {
      try self.init(uuid: Self._uuidBytes(initializingWith: initializer))
    }

    package static func _uuidBytes(copying bytes: RawSpan) -> UUIDBytes {
      precondition(
        bytes.byteCount == MemoryLayout<UUIDBytes>.size,
        "A UUID requires exactly 16 bytes, but \(bytes.byteCount) were provided."
      )
      return bytes.withUnsafeBytes { $0.loadUnaligned(as: UUIDBytes.self) }
    }

    package static func _uuidBytes<E: Error>(
      initializingWith initializer: (inout OutputRawSpan) throws(E) -> Void
    ) throws(E) -> UUIDBytes {
      var bytes = Self.nilUUIDBytes
      try withUnsafeMutableBytes(of: &bytes) { buffer throws(E) in
        var output = OutputRawSpan(buffer: buffer, initializedCount: 0)
        try initializer(&output)
        precondition(
          output.byteCount == MemoryLayout<UUIDBytes>.size,
          "A UUID requires exactly 16 bytes, but \(output.byteCount) were provided."
        )
        _ = output.finalize(for: buffer)
      }
      return bytes
    }
  }
#endif

// MARK: - Bytes

#if compiler(>=6.2.3) && hasFeature(Lifetimes) && hasFeature(AddressableTypes) && hasFeature(BuiltinModule)
  extension UUIDV7 {
    /// A `RawSpan` view of this UUID's 16 bytes.
    public var bytes: RawSpan {
      @_lifetime(borrow self)
      borrowing get {
        let pointer = UnsafeRawPointer(Builtin.addressOfBorrow(self))
        let span = RawSpan(_unsafeStart: pointer, byteCount: MemoryLayout<UUIDBytes>.size)
        return _overrideLifetime(span, borrowing: self)
      }
    }

    /// A `MutableRawSpan` view of this UUID's 16 bytes.
    ///
    /// Mutate the bytes in place, either through a method on this property, or by passing
    /// `&uuid.mutableBytes` to a function. The span cannot be stored in a variable, because this
    /// UUID is validated at the end of every mutation.
    ///
    /// - Precondition: The mutated bytes must be compliant with RFC 9562 UUID Version 7.
    public var mutableBytes: MutableRawSpan {
      _read {
        yield self.mutableBytesForReading()
      }
      _modify {
        defer { self.validateMutatedBytes() }
        var span = self.mutableBytesForWriting()
        yield &span
      }
    }

    @_lifetime(borrow self)
    private borrowing func mutableBytesForReading() -> MutableRawSpan {
      let pointer = UnsafeMutableRawPointer(
        mutating: UnsafeRawPointer(Builtin.addressOfBorrow(self))
      )
      let span = MutableRawSpan(_unsafeStart: pointer, byteCount: MemoryLayout<UUIDBytes>.size)
      return _overrideLifetime(span, borrowing: self)
    }

    @_lifetime(&self)
    private mutating func mutableBytesForWriting() -> MutableRawSpan {
      let pointer = UnsafeMutableRawPointer(Builtin.addressof(&self))
      let span = MutableRawSpan(_unsafeStart: pointer, byteCount: MemoryLayout<UUIDBytes>.size)
      return _overrideLifetime(span, mutating: &self)
    }

    private func validateMutatedBytes() {
      precondition(
        Self(uuid: self.uuid) != nil,
        "The mutated bytes of a UUIDV7 must be compliant with RFC 9562 UUID Version 7."
      )
    }
  }
#endif

// MARK: - UUID String

extension UUIDV7 {
  /// Attempts to create a ``UUIDV7`` from a UUID String.
  ///
  /// The UUID String must be compliant with RFC 9562 UUID Version 7, and must have the 36 character
  /// hyphenated form, such as “019B1FC9-11AE-7850-99CA-C24474C79EA9”. Hex digits may be uppercase
  /// or lowercase.
  ///
  /// - Parameter uuidString: A UUID String.
  public init?(uuidString: String) {
    guard let bytes = Self.uuidBytes(from: uuidString) else { return nil }
    self.init(uuid: bytes)
  }

  /// Returns a string created from the UUID, such as “019B1FC9-11AE-7850-99CA-C24474C79EA9”.
  public var uuidString: String {
    Self._uuidString(self.uuid, lowercased: false)
  }

  /// Returns a lowercase string created from the UUID, such as
  /// “019b1fc9-11ae-7850-99ca-c24474c79ea9”.
  public var lowercasedUUIDString: String {
    Self._uuidString(self.uuid, lowercased: true)
  }
}

// MARK: - Dynamic Member Lookup

#if (!SWIFT_UUIDV7_PACKAGE_BUILD || SwiftUUIDV7Foundation) && (canImport(FoundationEssentials) || canImport(Foundation))
  extension UUIDV7 {
    public subscript<Value>(dynamicMember keyPath: KeyPath<UUID, Value>) -> Value {
      self.rawValue[keyPath: keyPath]
    }
  }
#endif

// MARK: - Codable

extension UUIDV7: Encodable {
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(self.uuidString)
  }
}

extension UUIDV7: Decodable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    let uuidString = try container.decode(String.self)
    guard let bytes = Self.uuidBytes(from: uuidString) else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: decoder.codingPath,
          debugDescription: "Attempted to decode UUID from invalid UUID string."
        )
      )
    }
    guard let uuid = Self(uuid: bytes) else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: decoder.codingPath,
          debugDescription:
            "Attempted to decode a UUID that is not a version 7, RFC 9562 variant UUID."
        )
      )
    }
    self = uuid
  }
}

// MARK: - CustomStringConvertible

extension UUIDV7: CustomStringConvertible {
  public var description: String {
    self.uuidString
  }
}

// MARK: - CustomDebugStringConvertible

extension UUIDV7: CustomDebugStringConvertible {
  public var debugDescription: String {
    self.uuidString
  }
}

// MARK: - CustomReflectable

extension UUIDV7: CustomReflectable {
  public var customMirror: Mirror {
    Mirror(self, children: [], displayStyle: .struct)
  }
}

// MARK: - Comparable

extension UUIDV7: Comparable {
  public static func == (lhs: UUIDV7, rhs: UUIDV7) -> Bool {
    withUnsafeBytes(of: lhs.uuid) { lhs in
      withUnsafeBytes(of: rhs.uuid) { rhs in
        lhs.elementsEqual(rhs)
      }
    }
  }

  public static func < (lhs: UUIDV7, rhs: UUIDV7) -> Bool {
    withUnsafePointer(to: lhs) { lhs in
      withUnsafePointer(to: rhs) { rhs in
        memcmp(lhs, rhs, MemoryLayout<UUIDV7>.size) < 0
      }
    }
  }
}

// MARK: - Basic Conformances

extension UUIDV7: Hashable {
  public func hash(into hasher: inout Hasher) {
    withUnsafeBytes(of: self.uuid) { hasher.combine(bytes: $0) }
  }
}
extension UUIDV7: Sendable {}

// MARK: - RawRepresentable

#if (!SWIFT_UUIDV7_PACKAGE_BUILD || SwiftUUIDV7Foundation) && (canImport(FoundationEssentials) || canImport(Foundation))
  extension UUIDV7: RawRepresentable {
    /// This UUID as a Foundation UUID.
    public var rawValue: UUID {
      UUID(uuid: self.uuid)
    }

    public init?(rawValue: UUID) {
      self.init(uuid: rawValue.uuid)
    }
  }
#endif

// MARK: - Private Helpers

extension UUIDV7 {
  package static func _platformTimeIntervalSince1970() -> TimeInterval {
    #if os(Windows)
      var fileTime = FILETIME()
      GetSystemTimePreciseAsFileTime(&fileTime)
      let ticks = (UInt64(fileTime.dwHighDateTime) << 32) | UInt64(fileTime.dwLowDateTime)
      return TimeInterval(ticks) / 10_000_000 - 11_644_473_600
    #elseif os(WASI)
      var timestamp: __wasi_timestamp_t = 0
      _ = __wasi_clock_time_get(0, 1_000_000, &timestamp)
      return TimeInterval(timestamp) / 1_000_000_000
    #else
      var time = timespec()
      clock_gettime(CLOCK_REALTIME, &time)
      return TimeInterval(time.tv_sec) + TimeInterval(time.tv_nsec) / 1_000_000_000
    #endif
  }

  package static func randomBytes(using generator: inout some RandomNumberGenerator) -> UUIDBytes {
    let high = UInt64.random(in: .min ... .max, using: &generator)
    let low = UInt64.random(in: .min ... .max, using: &generator)
    return unsafeBitCast((high.bigEndian, low.bigEndian), to: UUIDBytes.self)
  }

  private static let nilUUIDBytes: UUIDBytes = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
}

// MARK: - String Conversions

extension UUIDV7 {
  private static func uuidBytes(from uuidString: String) -> UUIDBytes? {
    guard uuidString.utf8.count == 36 else { return nil }
    if let bytes = uuidString.utf8.withContiguousStorageIfAvailable(Self.uuidBytes(fromUTF8:)) {
      return bytes
    }
    var uuidString = uuidString
    return uuidString.withUTF8(Self.uuidBytes(fromUTF8:))
  }
}

#if canImport(CUUIDV7) && (arch(arm64) || arch(x86_64)) && !os(Windows)
  extension UUIDV7 {
    private static func uuidBytes(fromUTF8 utf8: UnsafeBufferPointer<UInt8>) -> UUIDBytes? {
      guard uuidv7_is_supported() else { return Self.portableUUIDBytes(fromUTF8: utf8) }
      let result = uuidv7_decode(utf8.baseAddress!)
      return result.is_valid ? unsafeBitCast(result.bytes.words, to: UUIDBytes.self) : nil
    }

    package static func _uuidString(_ uuid: UUIDBytes, lowercased: Bool) -> String {
      guard uuidv7_is_supported() else {
        return Self.portableUUIDString(uuid, lowercased: lowercased)
      }
      let uuid = uuidv7_bytes(words: unsafeBitCast(uuid, to: (UInt64, UInt64).self))
      return String(unsafeUninitializedCapacity: 36) { buffer in
        uuidv7_encode(uuid, buffer.baseAddress!, lowercased)
        return 36
      }
    }
  }
#else
  extension UUIDV7 {
    private static func uuidBytes(fromUTF8 utf8: UnsafeBufferPointer<UInt8>) -> UUIDBytes? {
      Self.portableUUIDBytes(fromUTF8: utf8)
    }

    package static func _uuidString(_ uuid: UUIDBytes, lowercased: Bool) -> String {
      Self.portableUUIDString(uuid, lowercased: lowercased)
    }
  }
#endif

extension UUIDV7 {
  private static let hyphen = UInt8(0x2D)
  private static let highBits = UInt64(0x8080_8080_8080_8080)

  private static func portableUUIDBytes(fromUTF8 utf8: UnsafeBufferPointer<UInt8>) -> UUIDBytes? {
    guard
      let string = utf8.baseAddress.map(UnsafeRawPointer.init),
      utf8[8] == Self.hyphen, utf8[13] == Self.hyphen, utf8[18] == Self.hyphen,
      utf8[23] == Self.hyphen
    else { return nil }
    return Self.uuidBytes(
      fromHexDigits: (
        Self.characters(string, at: 0),
        Self.characters(string, at: 9, and: 14),
        Self.characters(string, at: 19, and: 24),
        Self.characters(string, at: 28)
      )
    )
  }

  private static func characters(_ string: UnsafeRawPointer, at offset: Int) -> UInt64 {
    UInt64(littleEndian: string.loadUnaligned(fromByteOffset: offset, as: UInt64.self))
  }

  private static func characters(
    _ string: UnsafeRawPointer,
    at first: Int,
    and second: Int
  ) -> UInt64 {
    let low = UInt32(littleEndian: string.loadUnaligned(fromByteOffset: first, as: UInt32.self))
    let high = UInt32(littleEndian: string.loadUnaligned(fromByteOffset: second, as: UInt32.self))
    return UInt64(low) | UInt64(high) << 32
  }

  private static func uuidBytes(
    fromHexDigits digits: (UInt64, UInt64, UInt64, UInt64)
  ) -> UUIDBytes? {
    var validity = Self.highBits
    let words = (
      Self.bytes(fromHexDigits: digits.0, validity: &validity),
      Self.bytes(fromHexDigits: digits.1, validity: &validity),
      Self.bytes(fromHexDigits: digits.2, validity: &validity),
      Self.bytes(fromHexDigits: digits.3, validity: &validity)
    )
    guard validity == Self.highBits else { return nil }
    var bytes = Self.nilUUIDBytes
    withUnsafeMutableBytes(of: &bytes) { bytes in
      bytes.storeBytes(of: words.0.littleEndian, toByteOffset: 0, as: UInt32.self)
      bytes.storeBytes(of: words.1.littleEndian, toByteOffset: 4, as: UInt32.self)
      bytes.storeBytes(of: words.2.littleEndian, toByteOffset: 8, as: UInt32.self)
      bytes.storeBytes(of: words.3.littleEndian, toByteOffset: 12, as: UInt32.self)
    }
    return bytes
  }

  private static func bytes(fromHexDigits digits: UInt64, validity: inout UInt64) -> UInt32 {
    let isDigit = (digits &+ 0x5050_5050_5050_5050) & ~(digits &+ 0x4646_4646_4646_4646)
    let lowercased = digits | 0x2020_2020_2020_2020
    let isLetter = (lowercased &+ 0x1F1F_1F1F_1F1F_1F1F) & ~(lowercased &+ 0x1919_1919_1919_1919)
    validity &= (isDigit | isLetter) & ~digits

    let letterOffsets = ((digits >> 6) & 0x0101_0101_0101_0101) &* 9
    let values = (digits & 0x0F0F_0F0F_0F0F_0F0F) &+ letterOffsets
    var bytes = ((values << 4) | (values >> 8)) & 0x00FF_00FF_00FF_00FF
    bytes = (bytes | (bytes >> 8)) & 0x0000_FFFF_0000_FFFF
    return UInt32(truncatingIfNeeded: bytes | (bytes >> 16))
  }

  private static func portableUUIDString(_ uuid: UUIDBytes, lowercased: Bool) -> String {
    let letterOffset: UInt64 = lowercased ? 0x27 : 0x07
    var string: (UInt64, UInt64, UInt64, UInt64, UInt32) = (0, 0, 0, 0, 0)
    withUnsafeBytes(of: uuid) { uuid in
      withUnsafeMutableBytes(of: &string) { string in
        let digits = (
          Self.hexDigits(of: uuid, at: 0, letterOffset: letterOffset),
          Self.hexDigits(of: uuid, at: 4, letterOffset: letterOffset),
          Self.hexDigits(of: uuid, at: 8, letterOffset: letterOffset),
          Self.hexDigits(of: uuid, at: 12, letterOffset: letterOffset)
        )
        string.storeBytes(of: digits.0.littleEndian, toByteOffset: 0, as: UInt64.self)
        string.storeBytes(of: Self.hyphen, toByteOffset: 8, as: UInt8.self)
        string.storeBytes(
          of: UInt32(truncatingIfNeeded: digits.1).littleEndian,
          toByteOffset: 9,
          as: UInt32.self
        )
        string.storeBytes(of: Self.hyphen, toByteOffset: 13, as: UInt8.self)
        string.storeBytes(
          of: UInt32(truncatingIfNeeded: digits.1 >> 32).littleEndian,
          toByteOffset: 14,
          as: UInt32.self
        )
        string.storeBytes(of: Self.hyphen, toByteOffset: 18, as: UInt8.self)
        string.storeBytes(
          of: UInt32(truncatingIfNeeded: digits.2).littleEndian,
          toByteOffset: 19,
          as: UInt32.self
        )
        string.storeBytes(of: Self.hyphen, toByteOffset: 23, as: UInt8.self)
        string.storeBytes(
          of: UInt32(truncatingIfNeeded: digits.2 >> 32).littleEndian,
          toByteOffset: 24,
          as: UInt32.self
        )
        string.storeBytes(of: digits.3.littleEndian, toByteOffset: 28, as: UInt64.self)
      }
    }
    return withUnsafeBytes(of: string) { String(decoding: $0, as: UTF8.self) }
  }

  private static func hexDigits(
    of uuid: UnsafeRawBufferPointer,
    at offset: Int,
    letterOffset: UInt64
  ) -> UInt64 {
    let word = UInt32(bigEndian: uuid.loadUnaligned(fromByteOffset: offset, as: UInt32.self))
    var nibbles = UInt64(word)
    nibbles = (nibbles | (nibbles << 16)) & 0x0000_FFFF_0000_FFFF
    nibbles = (nibbles | (nibbles << 8)) & 0x00FF_00FF_00FF_00FF
    nibbles = (nibbles | (nibbles << 4)) & 0x0F0F_0F0F_0F0F_0F0F
    let isLetter = ((nibbles &+ 0x0606_0606_0606_0606) >> 4) & 0x0101_0101_0101_0101
    let letterOffsets = isLetter &* letterOffset
    return (nibbles &+ 0x3030_3030_3030_3030 &+ letterOffsets).byteSwapped
  }
}

// MARK: - Duration Helpers

extension Duration {
  package var uuidV7TimeInterval: TimeInterval {
    let (seconds, attoseconds) = self.components
    return TimeInterval(seconds) + TimeInterval(attoseconds) / 1_000_000_000_000_000_000
  }

  fileprivate var uuidV7Milliseconds: Int64 {
    let (seconds, attoseconds) = self.components
    return seconds * 1000 + attoseconds / 1_000_000_000_000_000
  }
}

// MARK: - Lock

struct _UUIDV7Lock<State> {
  private let buffer: ManagedBuffer<State, PlatformLock.Primitive>

  init(_ initial: State) {
    self.buffer = LockedBuffer.create(minimumCapacity: 1) { buffer in
      buffer.withUnsafeMutablePointerToElements { PlatformLock.initialize($0) }
      return initial
    }
  }
}

extension _UUIDV7Lock {
  private final class LockedBuffer: ManagedBuffer<State, PlatformLock.Primitive> {
    deinit {
      self.withUnsafeMutablePointerToElements { PlatformLock.deinitialize($0) }
    }
  }
}

extension _UUIDV7Lock {
  func withLock<R>(_ critical: (inout State) throws -> sending R) rethrows -> R {
    try self.buffer.withUnsafeMutablePointers { header, lock in
      PlatformLock.lock(lock)
      defer { PlatformLock.unlock(lock) }
      return try critical(&header.pointee)
    }
  }
}

// NB: This is safe because all mutable state is accessed only while holding `PlatformLock`.
extension _UUIDV7Lock: @unchecked Sendable where State: Sendable {}

// MARK: - PlatformLock

private enum PlatformLock {
  #if canImport(Darwin)
    typealias Primitive = os_unfair_lock
  #elseif canImport(Glibc) || canImport(Musl) || canImport(Bionic)
    #if os(FreeBSD) || os(OpenBSD)
      typealias Primitive = pthread_mutex_t?
    #else
      typealias Primitive = pthread_mutex_t
    #endif
  #elseif canImport(WinSDK)
    typealias Primitive = SRWLOCK
  #elseif arch(wasm32)
    typealias Primitive = Int
  #else
    #error("Unsupported platform")
  #endif

  typealias Pointer = UnsafeMutablePointer<Primitive>

  static func initialize(_ platformLock: Pointer) {
    #if canImport(Darwin)
      platformLock.initialize(to: os_unfair_lock())
    #elseif canImport(Glibc) || canImport(Musl) || canImport(Bionic)
      let result = pthread_mutex_init(platformLock, nil)
      precondition(result == 0, "pthread_mutex_init failed")
    #elseif canImport(WinSDK)
      InitializeSRWLock(platformLock)
    #elseif arch(wasm32)
      platformLock.initialize(to: 0)
    #else
      #error("Unsupported platform")
    #endif
  }

  static func deinitialize(_ platformLock: Pointer) {
    #if canImport(Glibc) || canImport(Musl) || canImport(Bionic)
      let result = pthread_mutex_destroy(platformLock)
      precondition(result == 0, "pthread_mutex_destroy failed")
    #endif
    platformLock.deinitialize(count: 1)
  }

  static func lock(_ platformLock: Pointer) {
    #if canImport(Darwin)
      os_unfair_lock_lock(platformLock)
    #elseif canImport(Glibc) || canImport(Musl) || canImport(Bionic)
      pthread_mutex_lock(platformLock)
    #elseif canImport(WinSDK)
      AcquireSRWLockExclusive(platformLock)
    #elseif arch(wasm32)
    #else
      #error("Unsupported platform")
    #endif
  }

  static func unlock(_ platformLock: Pointer) {
    #if canImport(Darwin)
      os_unfair_lock_unlock(platformLock)
    #elseif canImport(Glibc) || canImport(Musl) || canImport(Bionic)
      let result = pthread_mutex_unlock(platformLock)
      precondition(result == 0, "pthread_mutex_unlock failed")
    #elseif canImport(WinSDK)
      ReleaseSRWLockExclusive(platformLock)
    #elseif arch(wasm32)
    #else
      #error("Unsupported platform")
    #endif
  }
}

// MARK: - GenerationState

private struct GenerationState {
  static nonisolated(unsafe) let shared = _UUIDV7Lock(Self())

  var monotonicity = MonotonicityState()
  var random = RandomUUIDBytesGenerator()

  private init() {}
}

// MARK: - MonotonicityState

private struct MonotonicityState: Sendable {
  private var previousTimestamp = UInt64(0)
  private var sequence = UInt16(0)
  private var offset = UInt64(0)
}

extension MonotonicityState {
  mutating func nextMillisWithSequence(
    timeIntervalSince1970 timeInterval: TimeInterval
  ) -> (UInt64, UInt16) {
    var currentMillis = UInt64(timeInterval * 1000) &+ self.offset
    if self.previousTimestamp == currentMillis {
      self.sequence &+= 1
    } else if currentMillis < self.previousTimestamp {
      self.sequence &+= 1
      self.offset = self.previousTimestamp - currentMillis
      currentMillis = self.previousTimestamp
    } else {
      self.offset = 0
      self.sequence = 0
    }
    if self.sequence > 0xFFF {
      self.sequence = 0
      currentMillis &+= 1
    }
    self.previousTimestamp = currentMillis
    return (currentMillis, self.sequence)
  }
}

// MARK: - RandomUUIDBytesGenerator

private struct RandomUUIDBytesGenerator {
  private static let cacheSize = 256

  private var cache = UnsafeMutablePointer<UUIDBytes>.allocate(capacity: Self.cacheSize)
  private var cacheIndex = 0
}

extension RandomUUIDBytesGenerator {
  mutating func next() -> UUIDBytes {
    defer { self.cacheIndex = (self.cacheIndex + 1) % Self.cacheSize }
    if self.cacheIndex == 0 {
      self.readBytes()
    }
    return self.cache[self.cacheIndex]
  }
}

extension RandomUUIDBytesGenerator {
  #if os(Windows)
    private func readBytes() {
      BCryptGenRandom(
        nil,
        self.cache,
        UInt32(MemoryLayout<UUIDBytes>.size * Self.cacheSize),
        UInt32(BCRYPT_RNG_USE_ENTROPY_IN_BUFFER | BCRYPT_USE_SYSTEM_PREFERRED_RNG)
      )
    }
  #elseif os(WASI)
    private func readBytes() {
      _ = __wasi_random_get(
        self.cache,
        __wasi_size_t(MemoryLayout<UUIDBytes>.size * Self.cacheSize)
      )
    }
  #elseif canImport(Darwin) || os(Android) || os(FreeBSD) || os(OpenBSD)
    private func readBytes() {
      arc4random_buf(self.cache, MemoryLayout<UUIDBytes>.size * Self.cacheSize)
    }
  #else
    private func readBytes() {
      let fd = open("/dev/urandom", O_RDONLY)
      read(fd, self.cache, MemoryLayout<UUIDBytes>.size * Self.cacheSize)
      close(fd)
    }
  #endif
}
