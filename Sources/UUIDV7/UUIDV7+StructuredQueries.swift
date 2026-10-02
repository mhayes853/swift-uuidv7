#if SwiftUUIDV7StructuredQueries
  #if canImport(FoundationEssentials)
    import FoundationEssentials
  #else
    import Foundation
  #endif
  import StructuredQueriesCore
  import StructuredQueriesSQLiteCore

  // MARK: - QueryBindable

  extension UUIDV7: QueryBindable {}

  // MARK: - BytesRepresentation

  extension UUIDV7 {
    /// A query expression representing a ``UUIDV7`` as bytes.
    ///
    /// ```swift
    /// @Table
    /// struct Item {
    ///   @Column(as: UUIDV7.BytesRepresentation.self)
    ///   let id: UUIDV7
    /// }
    ///
    /// Item.insert { $0.id } values: { UUIDV7() }
    /// // INSERT INTO "items" ("id") VALUES (<blob>)
    /// ```
    public struct BytesRepresentation: QueryRepresentable {
      public var queryOutput: UUIDV7

      public init(queryOutput: UUIDV7) {
        self.queryOutput = queryOutput
      }
    }
  }

  extension Optional where Wrapped == UUIDV7 {
    public typealias BytesRepresentation = UUIDV7.BytesRepresentation?
  }

  extension UUIDV7.BytesRepresentation: QueryBindable {
    public var queryBinding: QueryBinding {
      .blob(withUnsafeBytes(of: queryOutput.uuid, [UInt8].init))
    }

    public init?(queryBinding: QueryBinding) {
      guard case .blob(let data) = queryBinding else { return nil }
      guard data.count == 16 else { return nil }
      let output = data.withUnsafeBytes { UUIDV7(uuid: $0.load(as: UUIDBytes.self)) }
      guard let output else { return nil }
      self.init(queryOutput: output)
    }
  }

  extension UUIDV7.BytesRepresentation: QueryDecodable {
    public init(decoder: inout some QueryDecoder) throws {
      let queryOutput = try [UInt8](decoder: &decoder)
      guard queryOutput.count == 16 else { throw InvalidBytes() }
      let output = queryOutput.withUnsafeBytes { UUIDV7(uuid: $0.load(as: UUIDBytes.self)) }
      guard let output else { throw InvalidBytes() }
      self.init(queryOutput: output)
    }

    private struct InvalidBytes: Error {}
  }

  extension UUIDV7.BytesRepresentation: SQLiteType {
    public static var typeAffinity: SQLiteTypeAffinity {
      [UInt8].typeAffinity
    }
  }

  // MARK: - UppercaseRepresentation

  extension UUIDV7 {
    /// A query expression representing a ``UUIDV7`` as an uppercased string.
    ///
    /// ```swift
    /// @Table
    /// struct Item {
    ///   @Column(as: UUIDV7.UppercaseRepresentation.self)
    ///   let id: UUIDV7
    /// }
    ///
    /// Item.insert { $0.id } values: { UUIDV7() }
    /// // INSERT INTO "items" ("id") VALUES ('1915C92E-B61E-7E3E-AFEA-2B5F3EA2DCF0')
    /// ```
    public struct UppercaseRepresentation: QueryRepresentable {
      public var queryOutput: UUIDV7

      public init(queryOutput: UUIDV7) {
        self.queryOutput = queryOutput
      }
    }
  }

  extension Optional where Wrapped == UUIDV7 {
    public typealias UppercaseRepresentation = UUIDV7.UppercaseRepresentation?
  }

  extension UUIDV7.UppercaseRepresentation: QueryBindable {
    public var queryBinding: QueryBinding {
      .text(self.queryOutput.uuidString.uppercased())
    }

    public init?(queryBinding: QueryBinding) {
      guard case .text(let uuidString) = queryBinding else { return nil }
      guard let uuid = UUIDV7(uuidString: uuidString) else { return nil }
      self.init(queryOutput: uuid)
    }
  }

  extension UUIDV7.UppercaseRepresentation: QueryDecodable {
    public init(decoder: inout some QueryDecoder) throws {
      guard let uuid = try UUIDV7(uuidString: String(decoder: &decoder)) else {
        throw InvalidString()
      }
      self.init(queryOutput: uuid)
    }

    private struct InvalidString: Error {}
  }

  extension UUIDV7.UppercaseRepresentation: SQLiteType {
    public static var typeAffinity: SQLiteTypeAffinity {
      String.typeAffinity
    }
  }

  // MARK: - SQLiteUUIDV7

  /// A namespace for UUIDV7 SQLite functions.
  ///
  /// Use these functions to generate, parse, and extract data from UUIDV7s in queries.
  ///
  /// Each SQL function is represented by a `ScalarDatabaseFunction` from StructuredQueries, and
  /// must be registered on your database connection before it can be used in a query. The exact
  /// registration API depends on the database driver you use with StructuredQueries. For
  /// instance, when using SQLiteData, you can register all functions inside a `Configuration` in a
  /// `bootstrapDatabase` function:
  ///
  /// ```swift
  /// import Dependencies
  /// import SQLiteData
  /// import UUIDV7
  ///
  /// extension DependencyValues {
  ///   mutating func bootstrapDatabase() throws {
  ///     var configuration = Configuration()
  ///     configuration.prepareDatabase { db in
  ///       SQLiteUUIDV7.allFunctions.forEach { db.add(function: $0) }
  ///     }
  ///     let database = try SQLiteData.defaultDatabase(configuration: configuration)
  ///     var migrator = DatabaseMigrator()
  ///     try migrator.migrate(database)
  ///     defaultDatabase = database
  ///   }
  /// }
  /// ```
  ///
  /// You can also register functions individually through their static properties, such as
  /// ``toDateFunction``:
  ///
  /// ```swift
  /// configuration.prepareDatabase { db in
  ///   db.add(function: SQLiteUUIDV7.toDateFunction)
  /// }
  /// ```
  ///
  /// Then you can use the functions in queries:
  ///
  /// ```swift
  /// @Table
  /// struct Item {
  ///   let id: UUIDV7
  ///   let idString: String
  ///   let createdAt: Date
  /// }
  ///
  /// // Generate a random UUIDV7
  /// Item.select { _ in SQLiteUUIDV7.uuidv7() }
  /// // SELECT "uuidv7"() FROM "items"
  ///
  /// // Convert UUIDV7 to lowercase text
  /// Item.select { SQLiteUUIDV7.toText($0.id) }
  /// // SELECT "uuidv7_to_text"("items"."id") FROM "items"
  /// ```
  public enum SQLiteUUIDV7 {
    /// All UUIDV7 SQL functions.
    ///
    /// Register each of these functions on your database connection to use the query expressions
    /// in this namespace.
    public static var allFunctions: [any ScalarDatabaseFunction] {
      [
        Self.uuidv7Function,
        Self.fromTextFunction,
        Self.fromDateFunction,
        Self.fromUnixEpochFunction,
        Self.toDateFunction,
        Self.toTextFunction,
        Self.toUnixEpochFunction
      ]
    }

    /// Generates a random ``UUIDV7``.
    ///
    /// This calls the `uuidv7` SQL function.
    ///
    /// ```swift
    /// Item.select { _ in SQLiteUUIDV7.uuidv7() }
    /// // SELECT "uuidv7"() FROM "items"
    /// ```
    ///
    /// - Returns: A query expression for a random UUIDV7.
    public static func uuidv7() -> some QueryExpression<UUIDV7> {
      Self.uuidv7Function()
    }

    /// Parses a ``UUIDV7`` from a UUID string.
    ///
    /// This calls the `uuidv7_from_text` SQL function.
    ///
    /// ```swift
    /// Item.select { SQLiteUUIDV7.fromText($0.idString) }
    /// // SELECT uuidv7_from_text("items"."idString") FROM "items"
    /// ```
    ///
    /// > Warning: The SQL function returns `NULL` if the string is not a valid UUIDV7, which fails
    /// > to decode as a non-optional ``UUIDV7``. Use ``fromText(uuidString:)`` instead.
    ///
    /// - Parameter text: A query expression for the UUID string.
    /// - Returns: A query expression for the parsed UUIDV7.
    @available(
      *,
      deprecated,
      message: "Use 'fromText(uuidString:)', which returns an optional UUIDV7 for invalid strings."
    )
    public static func fromText(
      _ text: some QueryExpression<String>
    ) -> some QueryExpression<UUIDV7> {
      SQLQueryExpression("uuidv7_from_text(\(text))")
    }

    /// Parses a ``UUIDV7`` from a UUID string.
    ///
    /// This calls the `uuidv7_from_text` SQL function, which returns `NULL` if the string is not a
    /// valid UUIDV7.
    ///
    /// ```swift
    /// Item.select { SQLiteUUIDV7.fromText(uuidString: $0.idString) }
    /// // SELECT "uuidv7_from_text"("items"."idString") FROM "items"
    /// ```
    ///
    /// Use `map` to chain other UUIDV7 expressions onto the parsed value:
    ///
    /// ```swift
    /// Item.select { SQLiteUUIDV7.fromText(uuidString: $0.idString).map { $0.toDate() } }
    /// ```
    ///
    /// - Parameter uuidString: A query expression for the UUID string.
    /// - Returns: A query expression for the parsed UUIDV7, or `NULL` if the string is invalid.
    public static func fromText(
      uuidString: some QueryExpression<String>
    ) -> some QueryExpression<UUIDV7?> {
      Self.fromTextFunction(uuidString)
    }

    /// Parses a ``UUIDV7`` from a date.
    ///
    /// This calls the `uuidv7_from_date` SQL function.
    ///
    /// ```swift
    /// Item.select { SQLiteUUIDV7.fromDate($0.createdAt) }
    /// // SELECT "uuidv7_from_date"("items"."createdAt") FROM "items"
    /// ```
    ///
    /// - Parameter date: A query expression for the date.
    /// - Returns: A query expression for the parsed UUIDV7.
    public static func fromDate(
      _ date: some QueryExpression<Date>
    ) -> some QueryExpression<UUIDV7> {
      Self.fromDateFunction(date)
    }

    /// Parses a ``UUIDV7`` from a numerical unix epoch.
    ///
    /// This calls the `uuidv7_from_unixepoch` SQL function.
    ///
    /// ```swift
    /// Item.select { _ in SQLiteUUIDV7.fromUnixEpoch(1735689600.0) }
    /// // SELECT "uuidv7_from_unixepoch"(1735689600.0) FROM "items"
    /// ```
    ///
    /// - Parameter epoch: A query expression for the unix epoch (seconds since 1970).
    /// - Returns: A query expression for the parsed UUIDV7.
    public static func fromUnixEpoch(
      _ epoch: some QueryExpression<Double>
    ) -> some QueryExpression<UUIDV7> {
      Self.fromUnixEpochFunction(epoch)
    }

    /// Converts a ``UUIDV7`` to a date.
    ///
    /// This calls the `uuidv7_to_date` SQL function.
    ///
    /// ```swift
    /// Item.select { SQLiteUUIDV7.toDate($0.id) }
    /// // SELECT "uuidv7_to_date"("items"."id") FROM "items"
    /// ```
    ///
    /// - Parameter expression: A query expression for the UUIDV7.
    /// - Returns: A query expression for the date.
    public static func toDate(
      _ expression: some QueryExpression<UUIDV7>
    ) -> some QueryExpression<Date> {
      Self.toDateFunction(expression)
    }

    /// Converts a ``UUIDV7`` to a lowercase UUID string.
    ///
    /// This calls the `uuidv7_to_text` SQL function.
    ///
    /// ```swift
    /// Item.select { SQLiteUUIDV7.toText($0.id) }
    /// // SELECT "uuidv7_to_text"("items"."id") FROM "items"
    /// ```
    ///
    /// - Parameter expression: A query expression for the UUIDV7.
    /// - Returns: A query expression for the lowercase UUID string (e.g., "01990e14-53fe-7406-8bde-9bdc29d8d298").
    public static func toText(
      _ expression: some QueryExpression<UUIDV7>
    ) -> some QueryExpression<String> {
      Self.toTextFunction(expression)
    }

    /// Converts a ``UUIDV7`` to a numeric unix epoch.
    ///
    /// This calls the `uuidv7_to_unixepoch` SQL function.
    ///
    /// ```swift
    /// Item.select { SQLiteUUIDV7.toUnixEpoch($0.id) }
    /// // SELECT "uuidv7_to_unixepoch"("items"."id") FROM "items"
    /// ```
    ///
    /// - Parameter expression: A query expression for the UUIDV7.
    /// - Returns: A query expression for the unix epoch (seconds since 1970).
    public static func toUnixEpoch(
      _ expression: some QueryExpression<UUIDV7>
    ) -> some QueryExpression<Double> {
      Self.toUnixEpochFunction(expression)
    }
  }

  // MARK: - Functions

  extension SQLiteUUIDV7 {
    /// The `uuidv7` SQL function, which generates a random ``UUIDV7``.
    public static var uuidv7Function: some ScalarDatabaseFunction<(), UUIDV7> {
      GenerateFunction()
    }

    /// The `uuidv7_from_text` SQL function, which parses a ``UUIDV7`` from a UUID string.
    ///
    /// This function returns `NULL` if the string is not a valid UUIDV7.
    public static var fromTextFunction: some ScalarDatabaseFunction<String, UUIDV7?> {
      FromTextFunction()
    }

    /// The `uuidv7_from_date` SQL function, which creates a ``UUIDV7`` from a date.
    public static var fromDateFunction: some ScalarDatabaseFunction<Date, UUIDV7> {
      FromDateFunction()
    }

    /// The `uuidv7_from_unixepoch` SQL function, which creates a ``UUIDV7`` from a numerical
    /// unix epoch.
    public static var fromUnixEpochFunction: some ScalarDatabaseFunction<Double, UUIDV7> {
      FromUnixEpochFunction()
    }

    /// The `uuidv7_to_date` SQL function, which converts a ``UUIDV7`` to a date.
    ///
    /// This function returns `NULL` if the input is not a valid UUIDV7.
    public static var toDateFunction: some ScalarDatabaseFunction<UUIDV7, Date> {
      ToDateFunction()
    }

    /// The `uuidv7_to_text` SQL function, which converts a ``UUIDV7`` to a lowercased UUID
    /// string.
    ///
    /// This function returns `NULL` if the input is not a valid UUIDV7.
    public static var toTextFunction: some ScalarDatabaseFunction<UUIDV7, String> {
      ToTextFunction()
    }

    /// The `uuidv7_to_unixepoch` SQL function, which converts a ``UUIDV7`` to a numeric unix
    /// epoch.
    ///
    /// This function returns `NULL` if the input is not a valid UUIDV7.
    public static var toUnixEpochFunction: some ScalarDatabaseFunction<UUIDV7, Double> {
      ToUnixEpochFunction()
    }
  }

  extension SQLiteUUIDV7 {
    private struct GenerateFunction: ScalarDatabaseFunction, Hashable, Sendable {
      typealias Input = ()
      typealias Output = UUIDV7

      var name: String { "uuidv7" }
      var argumentCount: Int? { 0 }
      var isDeterministic: Bool { false }

      func invoke(_ decoder: inout some QueryDecoder) throws -> QueryBinding {
        UUIDV7().queryBinding
      }
    }

    private struct FromTextFunction: ScalarDatabaseFunction, Hashable, Sendable {
      typealias Input = String
      typealias Output = UUIDV7?

      var name: String { "uuidv7_from_text" }
      var argumentCount: Int? { 1 }
      var isDeterministic: Bool { true }

      func invoke(_ decoder: inout some QueryDecoder) throws -> QueryBinding {
        try decoder.decode(String.self).flatMap(UUIDV7.init(uuidString:)).queryBinding
      }
    }

    private struct FromDateFunction: ScalarDatabaseFunction, Hashable, Sendable {
      typealias Input = Date
      typealias Output = UUIDV7

      var name: String { "uuidv7_from_date" }
      var argumentCount: Int? { 1 }
      var isDeterministic: Bool { true }

      func invoke(_ decoder: inout some QueryDecoder) throws -> QueryBinding {
        try decoder.decode(Date.self).map { UUIDV7($0) }.queryBinding
      }
    }

    private struct FromUnixEpochFunction: ScalarDatabaseFunction, Hashable, Sendable {
      typealias Input = Double
      typealias Output = UUIDV7

      var name: String { "uuidv7_from_unixepoch" }
      var argumentCount: Int? { 1 }
      var isDeterministic: Bool { true }

      func invoke(_ decoder: inout some QueryDecoder) throws -> QueryBinding {
        try decoder.decode(Double.self).map { UUIDV7(timeIntervalSince1970: $0) }.queryBinding
      }
    }

    private struct ToDateFunction: ScalarDatabaseFunction, Hashable, Sendable {
      typealias Input = UUIDV7
      typealias Output = Date

      var name: String { "uuidv7_to_date" }
      var argumentCount: Int? { 1 }
      var isDeterministic: Bool { true }

      func invoke(_ decoder: inout some QueryDecoder) throws -> QueryBinding {
        try self.decodeUUIDV7(from: &decoder)?.date.queryBinding ?? .null
      }
    }

    private struct ToTextFunction: ScalarDatabaseFunction, Hashable, Sendable {
      typealias Input = UUIDV7
      typealias Output = String

      var name: String { "uuidv7_to_text" }
      var argumentCount: Int? { 1 }
      var isDeterministic: Bool { true }

      func invoke(_ decoder: inout some QueryDecoder) throws -> QueryBinding {
        try self.decodeUUIDV7(from: &decoder)?.uuidString.lowercased().queryBinding ?? .null
      }
    }

    private struct ToUnixEpochFunction: ScalarDatabaseFunction, Hashable, Sendable {
      typealias Input = UUIDV7
      typealias Output = Double

      var name: String { "uuidv7_to_unixepoch" }
      var argumentCount: Int? { 1 }
      var isDeterministic: Bool { true }

      func invoke(_ decoder: inout some QueryDecoder) throws -> QueryBinding {
        try self.decodeUUIDV7(from: &decoder)?.timeIntervalSince1970.queryBinding ?? .null
      }
    }
  }

  extension ScalarDatabaseFunction where Input == UUIDV7 {
    fileprivate func decodeUUIDV7(from decoder: inout some QueryDecoder) throws -> UUIDV7? {
      try decoder.decode(UUID.self).flatMap(UUIDV7.init(rawValue:))
    }
  }

  // MARK: - UUIDV7 QueryExpression Helpers

  extension QueryExpression where QueryValue == UUIDV7 {
    /// Converts this ``UUIDV7`` expression to a date.
    ///
    /// This calls the `uuidv7_to_date` SQL function.
    ///
    /// ```swift
    /// Item.select { $0.id.toDate() }
    /// // SELECT "uuidv7_to_date"("items"."id") FROM "items"
    /// ```
    ///
    /// - Returns: A query expression for the date.
    public func toDate() -> some QueryExpression<Date> {
      SQLiteUUIDV7.toDate(self)
    }

    /// Converts this ``UUIDV7`` expression to a lowercase UUID string.
    ///
    /// This calls the `uuidv7_to_text` SQL function.
    ///
    /// ```swift
    /// Item.select { $0.id.toText() }
    /// // SELECT "uuidv7_to_text"("items"."id") FROM "items"
    /// ```
    ///
    /// - Returns: A query expression for the lowercase UUID string.
    public func toText() -> some QueryExpression<String> {
      SQLiteUUIDV7.toText(self)
    }

    /// Converts this ``UUIDV7`` expression to a numeric unix epoch.
    ///
    /// This calls the `uuidv7_to_unixepoch` SQL function.
    ///
    /// ```swift
    /// Item.select { $0.id.toUnixEpoch() }
    /// // SELECT "uuidv7_to_unixepoch"("items"."id") FROM "items"
    /// ```
    ///
    /// - Returns: A query expression for the unix epoch (seconds since 1970).
    public func toUnixEpoch() -> some QueryExpression<Double> {
      SQLiteUUIDV7.toUnixEpoch(self)
    }
  }
#endif
