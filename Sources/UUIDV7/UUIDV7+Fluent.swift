#if SwiftUUIDV7Fluent
  import FluentKit

  // MARK: - RandomGeneratable

  extension UUIDV7: RandomGeneratable {
    public static func generateRandom() -> Self {
      Self()
    }
  }

  // MARK: - ID

  extension IDProperty {
    /// Initializes an `ID` property with the key `.id` and type ``UUIDV7``.
    ///
    /// Use the `.init(custom:generatedBy:)` initializer to specify a custom ID key or type.
    public convenience init() where Value == UUIDV7 {
      self.init(custom: .id, generatedBy: .random)
    }
  }
#endif
