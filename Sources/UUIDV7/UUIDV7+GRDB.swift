#if SwiftUUIDV7GRDB
  import Foundation
  import GRDB

  // MARK: - GRDB Conformances

  extension UUIDV7: DatabaseValueConvertible {}
  extension UUIDV7: StatementColumnConvertible {}

  // MARK: - Database Functions

  extension DatabaseFunction {
    /// A SQL function that generates a random ``UUIDV7``.
    public static let uuidv7 = DatabaseFunction("uuidv7", argumentCount: 0, pure: false) { _ in
      UUIDV7()
    }

    /// A SQL function that parses a ``UUIDV7`` from a UUID string.
    public static let uuidv7FromText = DatabaseFunction(
      "uuidv7_from_text",
      argumentCount: 1,
      pure: true
    ) { args in
      String.fromDatabaseValue(args[0]).flatMap(UUIDV7.init(uuidString:))
    }

    /// A SQL function that parses a random ``UUIDV7`` from a date string.
    public static let uuidv7FromDate = DatabaseFunction(
      "uuidv7_from_date",
      argumentCount: 1,
      pure: true
    ) { args in
      Date.fromDatabaseValue(args[0]).map { UUIDV7($0) }
    }

    /// A SQL function that parses a random ``UUIDV7`` from a numerical unix epoch.
    public static let uuidv7FromUnixEpoch = DatabaseFunction(
      "uuidv7_from_unixepoch",
      argumentCount: 1,
      pure: true
    ) { args in
      TimeInterval.fromDatabaseValue(args[0]).map(UUIDV7.init(timeIntervalSince1970:))
    }

    /// A SQL function that converts a ``UUIDV7`` to a date.
    public static let uuidv7ToDate = DatabaseFunction(
      "uuidv7_to_date",
      argumentCount: 1,
      pure: true
    ) { args in
      UUIDV7.fromDatabaseValue(args[0])?.date
    }

    /// A SQL function that converts a ``UUIDV7`` to a UUID string.
    public static let uuidv7ToText = DatabaseFunction(
      "uuidv7_to_text",
      argumentCount: 1,
      pure: true
    ) { args in
      UUIDV7.fromDatabaseValue(args[0])?.uuidString
    }

    /// A SQL function that converts a ``UUIDV7`` to a numeric unix epoch.
    public static let uuidv7ToUnixEpoch = DatabaseFunction(
      "uuidv7_to_unixepoch",
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
    /// - `uuidv7`: Generates a random ``UUIDV7``.
    /// - `uuidv7_from_date`: Parses a random ``UUIDV7`` from a date.
    /// - `uuidv7_from_text`: Parses a random ``UUIDV7`` from a UUID string.
    /// - `uuidv7_from_unixepoch`: Parses a random ``UUIDV7`` from a numerical unix epoch.
    /// - `uuidv7_to_date`: Converts a ``UUIDV7`` to a date.
    /// - `uuidv7_to_text`: Converts a ``UUIDV7`` to a UUID string.
    /// - `uuidv7_to_unixepoch`: Converts a ``UUIDV7`` to a numeric unix epoch.
    public func addUUIDV7Functions() {
      self.add(function: .uuidv7)
      self.add(function: .uuidv7FromDate)
      self.add(function: .uuidv7FromText)
      self.add(function: .uuidv7FromUnixEpoch)
      self.add(function: .uuidv7ToDate)
      self.add(function: .uuidv7ToText)
      self.add(function: .uuidv7ToUnixEpoch)
    }
  }
#endif
