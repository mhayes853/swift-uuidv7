#if canImport(AppIntents)
  import AppIntents

  @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
  extension UUIDV7: EntityIdentifierConvertible {
    public var entityIdentifierString: String {
      self.rawValue.entityIdentifierString
    }

    public static func entityIdentifier(for entityIdentifierString: String) -> Self? {
      UUID.entityIdentifier(for: entityIdentifierString).flatMap(Self.init(rawValue:))
    }
  }
#endif
