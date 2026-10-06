#if SwiftUUIDV7Foundation
  #if canImport(FoundationEssentials)
    import FoundationEssentials
  #elseif canImport(Foundation)
    import Foundation
  #endif
#endif

#if SwiftUUIDV7Foundation && (canImport(FoundationEssentials) || canImport(Foundation))
  // MARK: - Constants

  extension UUID {
    /// A nil UUID defined by RFC 9562.
    @_disfavoredOverload
    @available(*, deprecated, renamed: "min")
    public static let `nil` = Self.min

    /// The min UUID, also known as the nil UUID defined by RFC 9562, where all bits are zero.
    @_disfavoredOverload
    public static let min = Self(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))

    /// A max UUID defined by RFC 9562.
    @_disfavoredOverload
    public static let max = Self(
      uuid: (
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF
      )
    )
  }

  // MARK: - Version

  extension UUID {
    /// The version number of this UUID as defined by RFC 9562.
    @_disfavoredOverload
    public var version: Int {
      Int(self.uuid.6 >> 4)
    }
  }

  // MARK: - Variant

  extension UUID {
    /// The variant of this UUID as defined by RFC 9562.
    @_disfavoredOverload
    @available(*, deprecated, message: "Use UUIDVariant(uuid:) instead.")
    public var variant: UUIDVariant {
      UUIDVariant(uuid: self.uuid)
    }
  }
#endif
