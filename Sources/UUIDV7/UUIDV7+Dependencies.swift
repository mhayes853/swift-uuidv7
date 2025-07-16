#if SwiftUUIDV7Dependencies
  import Dependencies
  import Foundation

  // MARK: - Dependency Values

  extension DependencyValues {
    /// A dependency that generates ``UUIDV7`` instances.
    ///
    /// Introduce controllable UUID generation to your features by using the ``Dependency`` property
    /// wrapper with a key path to this property. The wrapped value is an instance of
    /// ``UUIDV7Generator``, which can be called with a closure to create UUIDs. (It can be called
    /// directly because it defines ``UUIDV7Generator/callAsFunction()``, which is called when you
    /// invoke the instance as you would invoke a function.)
    ///
    /// For example, you could introduce controllable UUID generation to an observable object model
    /// that creates to-dos with unique identifiers:
    ///
    /// ```swift
    /// @Observable
    /// final class TodosModel {
    ///   var todos: [Todo] = []
    ///
    ///   @ObservationIgnored
    ///   @Dependency(\.uuidv7) var uuid
    ///
    ///   func addButtonTapped() {
    ///     todos.append(Todo(id: uuidv7()))
    ///   }
    /// }
    /// ```
    ///
    /// By default, a "live" generator is supplied, which returns a random UUID when called by
    /// invoking `UUIDV7.init` under the hood.  When used in tests, an "unimplemented" generator that
    /// additionally reports test failures if invoked, unless explicitly overridden.
    ///
    /// To test a feature that depends on UUID generation, you can override its generator using
    /// `withDependencies` to override the underlying ``UUIDV7Generator``:
    ///
    ///   * ``UUIDV7Generator/incrementing(from:)-(()->TimeInterval)`` for reproducible UUIDs that
    ///   count up from a manually specified time interval.
    ///
    ///   * ``UUIDV7Generator/constant(_:)`` for a generator that always returns the given UUID.
    ///
    /// For example, you could test the to-do-creating model by supplying an
    /// ``UUIDV7Generator/incrementing(from:)-(()->TimeInterval)`` generator as a dependency:
    ///
    /// ```swift
    /// @Test
    /// func feature() {
    ///   let model = withDependencies {
    ///     $0.uuid = .incrementing(from: 0)
    ///   } operation: {
    ///     TodosModel()
    ///   }
    ///
    ///   model.addButtonTapped()
    ///   #expect(
    ///     model.todos == [
    ///       Todo(id: UUIDV7(timeIntervalSince1970: 0, 0))
    ///     ]
    ///   )
    /// }
    /// ```
    public var uuidv7: UUIDV7Generator {
      get { self[UUIDV7GeneratorKey.self] }
      set { self[UUIDV7GeneratorKey.self] = newValue }
    }

    private enum UUIDV7GeneratorKey: DependencyKey {
      static let liveValue = UUIDV7Generator()
    }
  }

  // MARK: - UUIDV7Generator

  /// A dependency that generates a UUID.
  ///
  /// See ``Dependencies/DependencyValues/uuidv7`` for more information.
  public struct UUIDV7Generator: Sendable {
    private let uuid: @Sendable () -> UUIDV7
    
    /// Initializes a UUID generator that generates a ``UUIDV7`` from a closure.
    ///
    /// - Parameter uuid: A closure that returns a `UUIDV7` when called.
    public init(_ uuid: @escaping @Sendable () -> UUIDV7 = { UUIDV7() }) {
      self.uuid = uuid
    }
  }

  extension UUIDV7Generator {
    /// A generator that returns a constant ``UUIDV7``.
    ///
    /// - Parameter uuid: A `UUIDV7` to return.
    /// - Returns: A generator that always returns the given `UUIDV7`.
    public static func constant(_ uuid: UUIDV7) -> Self {
      Self { uuid }
    }
  }

  extension UUIDV7Generator {
    /// A generator that generates UUIDs in incrementing order starting from `@Dependency(\.date)`.
    ///
    /// For example:
    ///
    /// ```swift
    /// let date = Date(/* ... */)
    /// withDependencies {
    ///   $0.date.now = date
    /// } operation: {
    ///   let generate = UUIDV7Generator.incrementingFromNow
    ///   generate()  // UUIDV7(date, 0)
    ///   generate()  // UUIDV7(date, 1)
    ///   generate()  // UUIDV7(date, 2)
    /// }
    /// ```
    public static var incrementingFromNow: Self {
      @Dependency(\.date) var date
      return .incrementing(from: date())
    }

    /// A generator that generates UUIDs in incrementing order starting from a specified date.
    ///
    /// For example:
    ///
    /// ```swift
    /// let date = Date(/* ... */)
    /// let generate = UUIDV7Generator.incrementing(from: date)
    /// generate()  // UUIDV7(date, 0)
    /// generate()  // UUIDV7(date, 1)
    /// generate()  // UUIDV7(date, 2)
    /// ```
    ///
    /// - Parameter date: The date to start generation from.
    public static func incrementing(
      from date: @autoclosure @escaping @Sendable () -> Date
    ) -> Self {
      .incrementing(from: date().timeIntervalSince1970)
    }

    /// A generator that generates UUIDs in incrementing order starting from a specified
    /// `TimeInterval`.
    ///
    /// For example:
    ///
    /// ```swift
    /// let interval = TimeInterval(/* ... */)
    /// let generate = UUIDV7Generator.incrementing(from: interval)
    /// generate()  // UUIDV7(timeIntervalSince1970: interval, 0)
    /// generate()  // UUIDV7(timeIntervalSince1970: interval, 1)
    /// generate()  // UUIDV7(timeIntervalSince1970: interval, 2)
    /// ```
    ///
    /// - Parameter date: The date to start generation from.
    public static func incrementing(
      from timeIntervalSince1970: @autoclosure @escaping @Sendable () -> TimeInterval
    ) -> Self {
      let count = Lock(UInt32(0))
      return Self {
        count.withLock { count in
          defer { count += 1 }
          return UUIDV7(timeIntervalSince1970: timeIntervalSince1970(), count)
        }
      }
    }
  }

  extension UUIDV7Generator {
    public func callAsFunction() -> UUIDV7 {
      self.uuid()
    }
  }

  // MARK: - UUIDGenerator Interop

  extension UUIDGenerator {
    /// A generator that returns raw UUIDs generated by ``Dependencies/DependencyValues/uuidv7``.
    public static var v7: Self {
      @Dependency(\.uuidv7) var uuidv7
      return .v7(uuidv7)
    }
    
    /// A generator that returns raw UUIDs generated by a specified ``UUIDV7Generator``.
    ///
    /// - Parameter generator: The generator to use.
    /// - Returns: A generator that always returns the raw UUID from generated `UUIDV7` instances.
    public static func v7(_ generator: UUIDV7Generator) -> Self {
      Self { generator().rawValue }
    }

    /// A generator that returns a constant UUID.
    ///
    /// - Parameter uuid: A ``UUIDV7`` to return.
    /// - Returns: A generator that always returns the given `UUIDV7` as a raw UUID.
    public static func constant(_ uuid: UUIDV7) -> Self {
      .constant(uuid.rawValue)
    }
  }
#endif
