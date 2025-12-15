#if canImport(Foundation)
  import Foundation

  // MARK: - Constants

  extension UUID {
    /// A nil UUID defined by RFC 9562.
    public static let `nil` = Self(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))

    /// A max UUID defined by RFC 9562.
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
    public var version: Int {
      Int(self.uuid.6 >> 4)
    }
  }

  // MARK: - Varian

  extension UUID {
    /// The variant of this UUID as defined by RFC 9562.
    public var variant: UUIDVariant {
      UUIDVariant(uuid: self.uuid)
    }
  }
#endif
