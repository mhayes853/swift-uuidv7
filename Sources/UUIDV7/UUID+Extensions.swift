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

  // MARK: - Variant

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
  }

  extension UUID {
    /// The variant of this UUID as defined by RFC 9562.
    public var variant: UUIDVariant {
      let x = self.uuid.8
      if x & 0x80 == 0x00 {
        return .ncs
      } else if x & 0xC0 == 0x80 {
        return .rfc9562
      } else if x & 0xE0 == 0xC0 {
        return .microsoft
      } else if x & 0xE0 == 0xE0 {
        return .future
      } else {
        return .future
      }
    }
  }
#endif
