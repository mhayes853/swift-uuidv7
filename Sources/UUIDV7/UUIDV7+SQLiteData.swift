#if SwiftUUIDV7SQLiteData
  import Foundation
  import SQLiteData
  import StructuredQueriesCore
  import StructuredQueriesSQLiteCore

  // MARK: - IdentifierStringConvertible

  extension UUIDV7: IdentifierStringConvertible {
    public var rawIdentifier: String { self.uuidString }

    public init?(rawIdentifier: String) {
      self.init(uuidString: rawIdentifier)
    }
  }

  // MARK: - SQLiteUUIDV7

  /// A namespace for UUIDV7 SQLite functions.
  ///
  /// Use these functions to generate, parse, and extract data from UUIDV7s in queries.
  ///
  /// To use these functions, you must first add them to your database connection by calling
  /// ``Database/addUUIDV7Functions()`` inside a `Configuration` in a `bootstrapDatabase` function:
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
  ///       db.addUUIDV7Functions()
  ///     }
  ///     let database = try SQLiteData.defaultDatabase(configuration: configuration)
  ///     var migrator = DatabaseMigrator()
  ///     try migrator.migrate(database)
  ///     defaultDatabase = database
  ///   }
  /// }
  /// ```
  ///
  /// Then you can use the functions in queries:
  ///
  /// ```swift
  /// @Table
  /// struct Item {
  ///   let id: UUIDV7
  /// }
  ///
  /// // Generate a random UUIDV7
  /// Item.select { SQLiteUUIDV7.uuidv7() }
  /// // SELECT "uuidv7"() FROM "items"
  ///
  /// // Convert UUIDV7 to lowercase text
  /// Item.select { SQLiteUUIDV7.toText($0.id) }
  /// // SELECT "uuidv7_to_text"("items"."id") FROM "items"
  /// ```
  public enum SQLiteUUIDV7 {
    /// Generates a random ``UUIDV7``.
    ///
    /// This calls the `uuidv7` SQL function.
    ///
    /// ```swift
    /// Item.select { SQLiteUUIDV7.uuidv7() }
    /// // SELECT "uuidv7"() FROM "items"
    /// ```
    ///
    /// - Returns: A query expression for a random UUIDV7.
    public static func uuidv7() -> some QueryExpression<UUIDV7> {
      SQLQueryExpression("uuidv7()")
    }

    /// Parses a ``UUIDV7`` from a UUID string.
    ///
    /// This calls the `uuidv7_from_text` SQL function.
    ///
    /// ```swift
    /// let uuidString = "01990e14-53fe-7406-8bde-9bdc29d8d298"
    /// Item.select { SQLiteUUIDV7.fromText($0.id) }
    /// // SELECT "uuidv7_from_text"("items"."id") FROM "items"
    /// ```
    ///
    /// - Parameter text: A query expression for the UUID string.
    /// - Returns: A query expression for the parsed UUIDV7.
    public static func fromText(
      _ text: some QueryExpression<String> & QueryBindable
    ) -> some QueryExpression<UUIDV7> {
      SQLQueryExpression("uuidv7_from_text(\(text))")
    }

    /// Parses a ``UUIDV7`` from a date.
    ///
    /// This calls the `uuidv7_from_date` SQL function.
    ///
    /// ```swift
    /// Item.select { SQLiteUUIDV7.fromDate($0.createdAt) }
    /// // SELECT "uuidv7_from_date"("items"."created_at") FROM "items"
    /// ```
    ///
    /// - Parameter date: A query expression for the date.
    /// - Returns: A query expression for the parsed UUIDV7.
    public static func fromDate(
      _ date: some QueryExpression<Date> & QueryBindable
    ) -> some QueryExpression<UUIDV7> {
      SQLQueryExpression("uuidv7_from_date(\(date))")
    }

    /// Parses a ``UUIDV7`` from a numerical unix epoch.
    ///
    /// This calls the `uuidv7_from_unixepoch` SQL function.
    ///
    /// ```swift
    /// Item.select { SQLiteUUIDV7.fromUnixEpoch(1735689600) }
    /// // SELECT "uuidv7_from_unixepoch"(1735689600) FROM "items"
    /// ```
    ///
    /// - Parameter epoch: A query expression for the unix epoch (seconds since 1970).
    /// - Returns: A query expression for the parsed UUIDV7.
    public static func fromUnixEpoch(
      _ epoch: some QueryExpression<Double> & QueryBindable
    ) -> some QueryExpression<UUIDV7> {
      SQLQueryExpression("uuidv7_from_unixepoch(\(epoch))")
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
    /// - Parameter uuid: A query expression for the UUIDV7.
    /// - Returns: A query expression for the date.
    public static func toDate(
      _ expression: some QueryExpression<UUIDV7>
    ) -> some QueryExpression<Date> {
      SQLQueryExpression("uuidv7_to_date(\(expression))")
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
    /// - Parameter uuid: A query expression for the UUIDV7.
    /// - Returns: A query expression for the lowercase UUID string (e.g., "01990e14-53fe-7406-8bde-9bdc29d8d298").
    public static func toText(
      _ expression: some QueryExpression<UUIDV7>
    ) -> some QueryExpression<String> {
      SQLQueryExpression("uuidv7_to_text(\(expression))")
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
    /// - Parameter uuid: A query expression for the UUIDV7.
    /// - Returns: A query expression for the unix epoch (seconds since 1970).
    public static func toUnixEpoch(
      _ expression: some QueryExpression<UUIDV7>
    ) -> some QueryExpression<Double> {
      SQLQueryExpression("uuidv7_to_unixepoch(\(expression))")
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
