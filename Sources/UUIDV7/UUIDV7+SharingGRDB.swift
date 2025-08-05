#if SwiftUUIDV7SharingGRDB
  import SharingGRDBCore

  extension UUIDV7: IdentifierStringConvertible {
    public var rawIdentifier: String { self.uuidString }

    public init?(rawIdentifier: String) {
      self.init(uuidString: rawIdentifier)
    }
  }
#endif
