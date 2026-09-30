#if SwiftUUIDV7SQLiteData
  import SQLiteData

  // MARK: - IdentifierStringConvertible

  extension UUIDV7: IdentifierStringConvertible {
    public var rawIdentifier: String { self.uuidString }

    public init?(rawIdentifier: String) {
      self.init(uuidString: rawIdentifier)
    }
  }
#endif
