#if SwiftUUIDV7Tagged
  import Tagged
  import Foundation

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
    ///   `01980c7f-b814-717d-b320-c7bc7b2d0c75` or `01980C7F-B814-717D-B320-C7BC7B2D0C75`.
    public init?(uuidString string: String) {
      guard let uuid = UUIDV7(uuidString: string) else { return nil }
      self.init(uuid)
    }
  }
#endif
