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

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct UUIDV7 {
    /// The raw bytes of this UUID.
    public let uuid: uuid_t

    /// Creates a UUID from the specified bytes.
    ///
    /// The bytes must indicate that the UUID is a version 7 UUID.
    ///
    /// - Parameter bytes: The bytes to use for the UUID.
    public init?(uuid: uuid_t) {
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
        let t1 = UInt64(self.uuid.0) << 40
        let t2 = UInt64(self.uuid.1) << 32
        let t3 = UInt64(self.uuid.2) << 24
        let t4 = UInt64(self.uuid.3) << 16
        let t5 = UInt64(self.uuid.4) << 8
        let t6 = UInt64(self.uuid.5)
        return TimeInterval(t1 | t2 | t3 | t4 | t5 | t6) / 1000
    }
}

extension UUIDV7 {
    /// The date embedded in this UUID.
    public var timestamp: Date {
        Date(timeIntervalSince1970: self.timeIntervalSince1970)
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
    @inlinable
    public init() {
        self.init(systemNow: Date().timeIntervalSince1970)
    }

    @usableFromInline
    package init(systemNow: TimeInterval) {
        let (millis, sequence) = MonotonicityState.current.withLock {
            $0.nextMillisWithSequence(timeIntervalSince1970: systemNow)
        }
        var bytes = UUID().uuid
        withUnsafePointer(to: sequence.bigEndian) { ptr in
            ptr.withMemoryRebound(to: (UInt8, UInt8).self, capacity: 1) {
                bytes.6 = $0.pointee.0
                bytes.7 = $0.pointee.1
            }
        }
        self.init(millis, bytes)
    }
}

// MARK: - Time Initializers

extension UUIDV7 {
    /// Creates a UUID with the specified unix epoch.
    ///
    /// This initializer does not implement sub-millisecond monotonicity, use ``init()`` instead if
    /// sub-millisecond monotonicity is needed.
    ///
    /// - Parameters:
    ///   - timeInterval: The `TimeInterval` since 00:00:00 UTC on 1 January 1970.
    ///   - bytes: The bytes to use for the UUID. The timestamp and version will be overwritten.
    @inlinable
    public init(timeIntervalSince1970 timeInterval: TimeInterval, bytes: uuid_t = UUID().uuid) {
        precondition(timeInterval >= 0, _negativeTimeStampMessage(timeInterval))
        self.init(UInt64(timeInterval * 1000), bytes)
    }

    @usableFromInline
    internal init(_ timeMillis: UInt64, _ bytes: uuid_t) {
        var bytes = bytes
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

extension UUIDV7 {
    /// Creates a UUID with the specified `Date`.
    ///
    /// This initializer does not implement sub-millisecond monotonicity, use ``init()`` instead if
    /// sub-millisecond monotonicity is needed.
    ///
    /// - Parameters:
    ///   - timestamp: The `Date` to embed in this UUID.
    ///   - bytes: The bytes to use for the UUID. The timestamp and version will be overwritten.
    @inlinable
    public init(timestamp: Date, bytes: uuid_t = UUID().uuid) {
        self.init(timeIntervalSince1970: timestamp.timeIntervalSince1970, bytes: bytes)
    }
}

@usableFromInline
package func _negativeTimeStampMessage(_ timeInterval: TimeInterval) -> String {
    let timeInterval = Date(timeIntervalSince1970: timeInterval)
    return "Cannot create a UUIDV7 with a timestamp before January 1, 1970. (Received: \(timeInterval))"
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
    public init?(_ uuid: Foundation.UUID) {
        self.init(rawValue: uuid)
    }
}

// MARK: - UUID String

extension UUIDV7 {
    /// Attempts to create a ``UUIDV7`` from a UUID String.
    ///
    /// The UUID String must be compliant with RFC 9562 UUID Version 7.
    ///
    /// - Parameter uuidString: A UUID String.
    public init?(uuidString: String) {
        guard let bytes = UUID(uuidString: uuidString) else { return nil }
        self.init(uuid: bytes.uuid)
    }

    /// Returns a string created from the UUID, such as “019B1FC9-11AE-7850-99CA-C24474C79EA9”.
    public var uuidString: String {
        self.rawValue.uuidString
    }
}

// MARK: - Codable

extension UUIDV7: Encodable {
    public func encode(to encoder: any Encoder) throws {
        try rawValue.encode(to: encoder)
    }
}

extension UUIDV7: Decodable {
    public init(from decoder: any Decoder) throws {
        let uuid = try UUID(from: decoder)
        guard let uuid = Self(uuid: uuid.uuid) else {
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
        withUnsafePointer(to: lhs) { lhs in
            withUnsafePointer(to: rhs) { rhs in
                memcmp(lhs, rhs, MemoryLayout<UUIDV7>.size) < 0
            }
        }
    }
}

// MARK: - Basic Conformances

extension UUIDV7: Hashable {}
extension UUIDV7: Sendable {}

// MARK: - RawRepresentable

extension UUIDV7: RawRepresentable {
    /// This UUID as a Foundation UUID.
    public var rawValue: Foundation.UUID {
        UUID(uuid: self.uuid)
    }

    public init?(rawValue: Foundation.UUID) {
        self.init(uuid: rawValue.uuid)
    }
}
