#if SwiftUUIDV7GRDB
  import Foundation
  import GRDB

  // MARK: - GRDB Conformances

  extension UUIDV7: DatabaseValueConvertible {}
  extension UUIDV7: StatementColumnConvertible {}

  // MARK: - Database Functions

  extension DatabaseFunction {
    /// A SQL function that generates a random ``UUIDV7``.
    public static let uuid7 = DatabaseFunction("uuid7", argumentCount: 0, pure: false) { _ in
      UUIDV7()
    }

    /// A SQL function that parses a ``UUIDV7`` from a UUID string.
    public static let uuid7FromText = DatabaseFunction(
      "uuid7_from_text",
      argumentCount: 1,
      pure: true
    ) { args in
      String.fromDatabaseValue(args[0]).flatMap(UUIDV7.init(uuidString:))
    }

    /// A SQL function that parses a random ``UUIDV7`` from a date string.
    public static let uuid7FromDate = DatabaseFunction(
      "uuid7_from_date",
      argumentCount: 1,
      pure: true
    ) { args in
      Date.fromDatabaseValue(args[0]).map { UUIDV7($0) }
    }

    /// A SQL function that parses a random ``UUIDV7`` from a numerical unix epoch.
    public static let uuid7FromUnixEpoch = DatabaseFunction(
      "uuid7_from_unixepoch",
      argumentCount: 1,
      pure: true
    ) { args in
      TimeInterval.fromDatabaseValue(args[0]).map(UUIDV7.init(timeIntervalSince1970:))
    }

    /// A SQL function that converts a ``UUIDV7`` to a date.
    public static let uuid7ToDate = DatabaseFunction(
      "uuid7_to_date",
      argumentCount: 1,
      pure: true
    ) { args in
      UUIDV7.fromDatabaseValue(args[0])?.date
    }

    /// A SQL function that converts a ``UUIDV7`` to a UUID string.
    public static let uuid7ToText = DatabaseFunction(
      "uuid7_to_text",
      argumentCount: 1,
      pure: true
    ) { args in
      UUIDV7.fromDatabaseValue(args[0])?.uuidString
    }

    /// A SQL function that converts a ``UUIDV7`` to a numeric unix epoch.
    public static let uuid7ToUnixEpoch = DatabaseFunction(
      "uuid7_to_unixepoch",
      argumentCount: 1,
      pure: true
    ) { args in
      UUIDV7.fromDatabaseValue(args[0])?.timeIntervalSince1970
    }
  }

  // MARK: - Add UUIDV7 Functions

  extension Database {
    /// Adds UUIDV7 functions to the database.
    ///
    /// Functions:
    /// - `uuid7`: Generates a random ``UUIDV7``.
    /// - `uuid7_from_date`: Parses a random ``UUIDV7`` from a date.
    /// - `uuid7_from_text`: Parses a random ``UUIDV7`` from a UUID string.
    /// - `uuid7_from_unixepoch`: Parses a random ``UUIDV7`` from a numerical unix epoch.
    /// - `uuid7_to_date`: Converts a ``UUIDV7`` to a date.
    /// - `uuid7_to_text`: Converts a ``UUIDV7`` to a UUID string.
    /// - `uuid7_to_unixepoch`: Converts a ``UUIDV7`` to a numeric unix epoch.
    public func addUUIDV7Functions() {
      self.add(function: .uuid7)
      self.add(function: .uuid7FromDate)
      self.add(function: .uuid7FromText)
      self.add(function: .uuid7FromUnixEpoch)
      self.add(function: .uuid7ToDate)
      self.add(function: .uuid7ToText)
      self.add(function: .uuid7ToUnixEpoch)
    }
  }
#endif
