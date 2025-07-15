#if SwiftUUIDV7Tagged
  import Tagged
  import Foundation

  #if canImport(AppIntents)
    import AppIntents
  #endif

  // MARK: - UUIDV7 Tagged

  extension Tagged where RawValue == UUIDV7 {
    /// Generates a tagged ``UUIDV7``.
    ///
    /// Equivalent to `Tagged<Tag, _>(UUIDV7(())`.
    public init() {
      self.init(UUIDV7())
    }

    /// Returns a tagged ``UUIDV7`` initialized to the current date and time.
    public static var now: Self { Self() }

    /// Creates a tagged ``UUIDV7`` from a date.
    ///
    /// - Parameter date: The date to use for the UUIDV7.
    public init(_ date: Date) {
      self.init(UUIDV7(date))
    }

    /// Creates a tagged ``UUIDV7`` from a string representation.
    ///
    /// - Parameter string: The string representation of a UUIDV7, such as
    ///   `01980c7f-b814-717d-b320-c7bc7b2d0c75`.
    public init?(uuidString string: String) {
      guard let uuid = UUIDV7(uuidString: string) else { return nil }
      self.init(uuid)
    }
  }

  // MARK: - App Intents

  #if canImport(AppIntents)
    @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
    extension Tagged: @retroactive EntityIdentifierConvertible where RawValue == UUIDV7 {
      public var entityIdentifierString: String {
        self.rawValue.entityIdentifierString
      }

      public static func entityIdentifier(for entityIdentifierString: String) -> Self? {
        Self(uuidString: entityIdentifierString)
      }
    }
  #endif
#endif
