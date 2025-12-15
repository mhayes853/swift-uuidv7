#if canImport(Darwin)
  import Darwin
#elseif canImport(Android)
  import Android
#elseif canImport(Glibc)
  import Glibc
#elseif canImport(Musl)
  import Musl
#elseif canImport(WinSDK)
  import WinSDK
#elseif os(WASI)
  import WASILibc
#endif

#if canImport(Foundation)
  import Foundation
#endif

#if canImport(Foundation)
  @dynamicMemberLookup
#endif
public struct UUIDV7 {
  /// The raw ``UUIDBytes`` of this UUID.
  public let uuid: UUIDBytes

  /// Creates a UUID from the specified bytes.
  ///
  /// The bytes must indicate that the UUID is a version 7 UUID.
  ///
  /// - Parameter bytes: The bytes to use for the UUID.
  public init?(uuid: UUIDBytes) {
    guard Self.isVersion7(uuid), Self.isRFC9562Variant(uuid) else { return nil }
    self.uuid = uuid
  }
}

// MARK: - Date

extension UUIDV7 {
  /// The timestamp embedded in this UUID.
  public var timeIntervalSince1970: TimeInterval {
    let t1 = UInt64(self.uuid.0) << 40
    let t2 = UInt64(self.uuid.1) << 32
    let t3 = UInt64(self.uuid.2) << 24
    let t4 = UInt64(self.uuid.3) << 16
    let t5 = UInt64(self.uuid.4) << 8
    let t6 = UInt64(self.uuid.5)
    return TimeInterval(t1 | t2 | t3 | t4 | t5 | t6) / 1000
  }
}

#if canImport(Foundation)
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
    self.init(systemNow: Self.platformTimeIntervalSince1970())
  }

  private init(systemNow: TimeInterval) {
    let (millis, sequence) = MonotonicityState.current.withLock {
      $0.nextMillisWithSequence(timeIntervalSince1970: systemNow)
    }
    var bytes = RandomUUIDBytesGenerator.shared.withLock { $0.next() }
    withUnsafePointer(to: sequence.bigEndian) { ptr in
      ptr.withMemoryRebound(to: (UInt8, UInt8).self, capacity: 1) {
        bytes.6 = $0.pointee.0
        bytes.7 = $0.pointee.1
      }
    }
    self.init(millis, &bytes)
  }
}

#if canImport(Foundation)
  extension UUIDV7 {
    package init(systemNow: Date) {
      self.init(systemNow: systemNow.timeIntervalSince1970)
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
    var bytes = RandomUUIDBytesGenerator.shared.withLock { $0.next() }
    self.init(timeInterval, &bytes)
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
    var bytes: UUIDBytes = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
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

#if canImport(Foundation)
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
  }
#endif

package func _negativeTimeStampMessage(_ timeInterval: TimeInterval) -> String {
  #if canImport(Foundation)
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

// MARK: - Basic Initializers

#if canImport(Foundation)
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

// MARK: - UUID String

extension UUIDV7 {
  /// Attempts to create a ``UUIDV7`` from a UUID String.
  ///
  /// The UUID String must be compliant with RFC 9562 UUID Version 7.
  ///
  /// - Parameter uuidString: A UUID String.
  public init?(uuidString: String) {
    guard let bytes = Self.uuidBytes(from: uuidString) else { return nil }
    self.init(uuid: bytes)
  }

  /// Returns a string created from the UUID, such as “019B1FC9-11AE-7850-99CA-C24474C79EA9”.
  public var uuidString: String {
    Self.string(from: self.uuid)
  }
}

// MARK: - Dynamic Member Lookup

#if canImport(Foundation)
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
    guard let uuid = Self(uuidString: uuidString) else {
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

// MARK: - CustomReflectable

extension UUIDV7: CustomReflectable {
  public var customMirror: Mirror {
    Mirror(self, children: [], displayStyle: .struct)
  }
}

// MARK: - Comparable

extension UUIDV7: Comparable {
  public static func < (lhs: UUIDV7, rhs: UUIDV7) -> Bool {
    withUnsafeBytes(of: lhs.uuid) { lhsPtr in
      withUnsafeBytes(of: rhs.uuid) { rhsPtr in
        memcmp(lhsPtr.baseAddress, rhsPtr.baseAddress, MemoryLayout<UUIDBytes>.size) < 0
      }
    }
  }
}

// MARK: - Basic Conformances

extension UUIDV7: Hashable {}
extension UUIDV7: Sendable {}

// MARK: - RawRepresentable

#if canImport(Foundation)
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
  private static func isVersion7(_ bytes: UUIDBytes) -> Bool {
    bytes.6 >> 4 == 0x7
  }

  private static func isRFC9562Variant(_ bytes: UUIDBytes) -> Bool {
    bytes.8 & 0xC0 == 0x80
  }

  private static func platformTimeIntervalSince1970() -> TimeInterval {
    #if canImport(Foundation)
      Date().timeIntervalSince1970
    #elseif os(WASI)
      var timestamp: __wasi_timestamp_t = 0
      _ = __wasi_clock_time_get(__WASI_CLOCKID_REALTIME, 1_000_000, &timestamp)
      return TimeInterval(timestamp) / 1_000_000_000
    #elseif os(Windows)
      var fileTime = FILETIME()
      GetSystemTimePreciseAsFileTime(&fileTime)
      let ticks = (UInt64(fileTime.dwHighDateTime) << 32) | UInt64(fileTime.dwLowDateTime)
      return TimeInterval(ticks) / 10_000_000 - 11_644_473_600
    #else
      var tv = timeval()
      gettimeofday(&tv, nil)
      return TimeInterval(tv.tv_sec) + TimeInterval(tv.tv_usec) / 1_000_000
    #endif
  }

  private static let hyphen = UInt8(0x2D)
  private static let hexLookup = [Character]("0123456789ABCDEF")
  private static let expectedHyphenIndices = Set([8, 13, 18, 23])

  private static func uuidBytes(from uuidString: String) -> UUIDBytes? {
    var nibbles = [UInt8]()
    nibbles.reserveCapacity(32)

    for (index, character) in uuidString.utf8.enumerated() {
      if character == Self.hyphen {
        guard Self.expectedHyphenIndices.contains(index) else { return nil }
        continue
      }
      guard let value = Self.hexValue(character) else { return nil }
      nibbles.append(value)
    }

    guard nibbles.count == 32 else { return nil }

    var byteArray = [UInt8](repeating: 0, count: 16)
    var nibbleIndex = 0
    for byteIndex in 0..<16 {
      let high = nibbles[nibbleIndex]
      let low = nibbles[nibbleIndex + 1]
      nibbleIndex += 2
      byteArray[byteIndex] = (high << 4) | low
    }

    return byteArray.withUnsafeBytes { $0.load(as: UUIDBytes.self) }
  }

  private static let hyphenPositions = Set([8, 12, 16, 20])

  private static func string(from bytes: UUIDBytes) -> String {
    withUnsafeBytes(of: bytes) { rawBytes in
      var output = ""
      output.reserveCapacity(36)

      var hexCount = 0
      for byte in rawBytes {
        let high = Int(byte >> 4)
        let low = Int(byte & 0x0F)

        output.append(Self.hexLookup[high])
        output.append(Self.hexLookup[low])

        hexCount += 2

        if Self.hyphenPositions.contains(hexCount) {
          output.append("-")
        }
      }
      return output
    }
  }

  private static let numericRange = UInt8(48)...57
  private static let uppercaseRange = UInt8(65)...70
  private static let lowercaseRange = UInt8(97)...102

  private static func hexValue(_ character: UInt8) -> UInt8? {
    switch character {
    case numericRange: character &- 48
    case uppercaseRange: character &- 55
    case lowercaseRange: character &- 87
    default: nil
    }
  }
}
