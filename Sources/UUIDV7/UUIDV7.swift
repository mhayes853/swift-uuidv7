import Foundation

// MARK: - UUIDV7

/// An RFC 9562 compliant UUID Version 7.
@dynamicMemberLookup
public struct UUIDV7: RawRepresentable {
  /// This UUID as a Foundation UUID.
  public let rawValue: UUID

  public init?(rawValue: UUID) {
    guard rawValue.version == 7, rawValue.variant == .rfc9562 else { return nil }
    self.rawValue = rawValue
  }
}

// MARK: - Date

extension UUIDV7 {
  /// The date embedded in this UUID.
  public var date: Date {
    Date(timeIntervalSince1970: self.timeIntervalSince1970)
  }

  /// The timestamp embedded in this UUID.
  public var timeIntervalSince1970: TimeInterval {
    let t1 = UInt64(self.rawValue.uuid.0) << 40
    let t2 = UInt64(self.rawValue.uuid.1) << 32
    let t3 = UInt64(self.rawValue.uuid.2) << 24
    let t4 = UInt64(self.rawValue.uuid.3) << 16
    let t5 = UInt64(self.rawValue.uuid.4) << 8
    let t6 = UInt64(self.rawValue.uuid.5)
    return TimeInterval(t1 | t2 | t3 | t4 | t5 | t6) / 1000
  }
}

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
    self.init(systemNow: Date())
  }

  package init(systemNow: Date) {
    let (millis, sequence) = MonotonicityState.current.withLock {
      $0.nextMillisWithSequence(timeIntervalSince1970: systemNow.timeIntervalSince1970)
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

// MARK: - Time Initializers

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
    var bytes = UUID.nil.uuid
    let byteCount = Int(ceil(Double(integer.bitWidth - integer.leadingZeroBitCount) / 8.0))
    withUnsafeMutablePointer(to: &bytes) { ptr in
      withUnsafePointer(to: integer) { integerPtr in
        UnsafeMutableRawPointer(ptr).advanced(by: MemoryLayout<uuid_t>.size - byteCount)
          .copyMemory(from: integerPtr, byteCount: byteCount)
      }
    }
    self.init(timeInterval, &bytes)
  }

  private init(_ timeInterval: TimeInterval, _ bytes: inout uuid_t) {
    precondition(timeInterval >= 0, _negativeTimeStampMessage(timeInterval))
    self.init(UInt64(timeInterval * 1000), &bytes)
  }

  private init(_ timeMillis: UInt64, _ bytes: inout uuid_t) {
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
    self.rawValue = UUID(uuid: bytes)
  }
}

package func _negativeTimeStampMessage(_ timeInterval: TimeInterval) -> String {
  let date = Date(timeIntervalSince1970: timeInterval)
  return "Cannot create a UUIDV7 with a timestamp before January 1, 1970. (Received: \(date))"
}

// MARK: - Now

extension UUIDV7 {
  /// Returns a ``UUIDV7`` initialized to the current date and time.
  public static var now: Self { Self() }
}

// MARK: - Basic Initializers

extension UUIDV7 {
  /// Attempts to create a ``UUIDV7`` from a Foundation UUID.
  ///
  /// The Foundation UUID must be compliant with RFC 9562 UUID Version 7.
  ///
  /// - Parameter uuid: A Foundation UUID.
  public init?(_ uuid: UUID) {
    self.init(rawValue: uuid)
  }

  /// Attempts to create a ``UUIDV7`` from a Foundation `uuid_t`.
  ///
  /// The Foundation UUID must be compliant with RFC 9562 UUID Version 7.
  ///
  /// - Parameter uuid: A Foundation `uuid_t`.
  public init?(uuid: uuid_t) {
    self.init(UUID(uuid: uuid))
  }

  /// Attempts to create a ``UUIDV7`` from a UUID String.
  ///
  /// The UUID String must be compliant with RFC 9562 UUID Version 7.
  ///
  /// - Parameter uuidString: A UUID String.
  public init?(uuidString: String) {
    guard let uuid = UUID(uuidString: uuidString) else { return nil }
    self.init(uuid)
  }
}

// MARK: - Dynamic Member Lookup

extension UUIDV7 {
  public subscript<Value>(dynamicMember keyPath: KeyPath<UUID, Value>) -> Value {
    self.rawValue[keyPath: keyPath]
  }
}

// MARK: - Codable

extension UUIDV7: Encodable {
  public func encode(to encoder: any Encoder) throws {
    try self.rawValue.encode(to: encoder)
  }
}

extension UUIDV7: Decodable {
  public init(from decoder: any Decoder) throws {
    let uuid = try UUID(from: decoder)
    guard let uuid = Self(uuid) else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: decoder.codingPath,
          debugDescription:
            "Attempted to decode a UUID with version \(uuid.version) and not version 7."
        )
      )
    }
    self = uuid
  }
}

// MARK: - CustomStringConvertible

extension UUIDV7: CustomStringConvertible {
  public var description: String {
    self.rawValue.description
  }
}

// MARK: - CustomReflectable

extension UUIDV7: CustomReflectable {
  public var customMirror: Mirror {
    self.rawValue.customMirror
  }
}

// MARK: - Comparable

extension UUIDV7: Comparable {
  public static func < (lhs: UUIDV7, rhs: UUIDV7) -> Bool {
    withUnsafePointer(to: lhs.rawValue.uuid) { lhs in
      withUnsafePointer(to: rhs.rawValue.uuid) { rhs in
        memcmp(lhs, rhs, MemoryLayout<uuid_t>.size) < 0
      }
    }
  }
}

// MARK: - Basic Conformances

extension UUIDV7: Hashable {}
extension UUIDV7: Sendable {}
