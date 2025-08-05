#if SwiftUUIDV7SharingGRDB
  import SharingGRDBCore

  #if SwiftUUIDV7Tagged
    import Tagged
  #endif

  extension UUIDV7: IdentifierStringConvertible {
    public var rawIdentifier: String { self.uuidString }

    public init?(rawIdentifier: String) {
      self.init(uuidString: rawIdentifier)
    }
  }

  #if SwiftUUIDV7Tagged
    extension Tagged: @retroactive IdentifierStringConvertible where RawValue == UUIDV7 {
      public var rawIdentifier: String { self.uuidString }

      public init?(rawIdentifier: String) {
        self.init(uuidString: rawIdentifier)
      }
    }
  #endif
#endif
