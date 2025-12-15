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
    } else if x & 0xE0 == 0xE0 {
      self = .future
    } else {
      self = .future
    }
  }
}
