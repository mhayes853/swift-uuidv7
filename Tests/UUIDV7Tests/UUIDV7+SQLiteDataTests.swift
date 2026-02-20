#if SwiftUUIDV7SQLiteData
  import Dependencies
  import DependenciesTestSupport
  import Foundation
  import SQLiteData
  import StructuredQueriesCore
  import StructuredQueriesSQLiteCore
  import Testing
  import UUIDV7

  @Table("dummy_rows")
  private struct DummyRow {
    @Column(as: UUIDV7.BytesRepresentation.self)
    var uuid: UUIDV7
  }

  @Suite(.dependencies { try $0.bootstrapDatabase() })
  struct UUIDV7SQLiteDataTests {
    @Test("Generates Random UUIDV7")
    func noArgsGeneratesRandomUUIDV7() async throws {
      @Dependency(\.defaultDatabase) var database

      let (uuid1, uuid2) = try await database.read { db in
        let uuid1 = try #require(
          UUIDV7(uuidString: DummyRow.select { _ in SQLiteUUIDV7.toText(SQLiteUUIDV7.uuidv7()) }.fetchOne(db)!)
        )
        let uuid2 = try #require(
          UUIDV7(uuidString: DummyRow.select { _ in SQLiteUUIDV7.toText(SQLiteUUIDV7.uuidv7()) }.fetchOne(db)!)
        )
        return (uuid1, uuid2)
      }
      #expect(uuid2 > uuid1)
    }

    @Test("Creates UUIDV7 From Date")
    func createsUUIDV7FromDate() async throws {
      @Dependency(\.defaultDatabase) var database

      let date = Date(staticISO8601: "2024-09-09T22:41:15+0000")
      let uuid = try await database.read { db in
        try #require(
          UUIDV7(
            uuidString: DummyRow.select { _ in SQLiteUUIDV7.toText(SQLiteUUIDV7.fromDate(date)) }.fetchOne(db)!
          )
        )
      }
      #expect(uuid.date == date)
    }

    @Test("Creates UUIDV7 From Time Interval")
    func createsUUIDV7FromTimeInterval() async throws {
      @Dependency(\.defaultDatabase) var database

      let date = Date(staticISO8601: "2024-09-09T22:41:15+0000")
      let uuid = try await database.read { db in
        try #require(
          UUIDV7(
            uuidString: DummyRow
              .select { _ in SQLiteUUIDV7.toText(SQLiteUUIDV7.fromUnixEpoch(date.timeIntervalSince1970)) }
              .fetchOne(db)!
          )
        )
      }
      #expect(uuid.date == date)
    }

    @Test("Creates UUIDV7 From Integer Time Interval")
    func createsUUIDV7FromIntegerTimeInterval() async throws {
      @Dependency(\.defaultDatabase) var database

      let date = Date(staticISO8601: "2024-09-09T22:41:15+0000")
      let uuid = try await database.read { db in
        try #require(
          UUIDV7(
            uuidString: DummyRow
              .select { _ in SQLiteUUIDV7.toText(SQLiteUUIDV7.fromUnixEpoch(Double(Int(date.timeIntervalSince1970)))) }
              .fetchOne(db)!
          )
        )
      }
      #expect(uuid.date == date)
    }

    @Test("Creates UUIDV7 From Unix Epoch")
    func createsUUIDV7FromUnixEpoch() async throws {
      @Dependency(\.defaultDatabase) var database

      let date = Date(staticISO8601: "2024-09-09T22:41:15+0000")
      let uuid = try await database.read { db in
        try #require(
          UUIDV7(
            uuidString: DummyRow.select { _ in SQLiteUUIDV7.toText(SQLiteUUIDV7.fromUnixEpoch(date.timeIntervalSince1970)) }
              .fetchOne(db)!
          )
        )
      }
      #expect(uuid.date == date)
    }

    @Test("Creates UUIDV7 From Integer Unix Epoch")
    func createsUUIDV7FromIntegerUnixEpoch() async throws {
      @Dependency(\.defaultDatabase) var database

      let date = Date(staticISO8601: "2024-09-09T22:41:15+0000")
      let uuid = try await database.read { db in
        try #require(
          UUIDV7(
            uuidString: DummyRow
              .select { _ in SQLiteUUIDV7.toText(SQLiteUUIDV7.fromUnixEpoch(Double(Int(date.timeIntervalSince1970)))) }
              .fetchOne(db)!
          )
        )
      }
      #expect(uuid.date == date)
    }

    @Test("Creates UUIDV7 From Date String")
    func createsUUIDV7FromDateString() async throws {
      @Dependency(\.defaultDatabase) var database

      let formatter = DateFormatter()
      formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
      formatter.timeZone = TimeZone(secondsFromGMT: 0)
      let date = try #require(formatter.date(from: "2024-09-09 22:41:15"))

      let uuid = try await database.read { db in
        try #require(
          UUIDV7(
            uuidString: DummyRow.select { _ in
              SQLiteUUIDV7.toText(SQLiteUUIDV7.fromDate(date))
            }.fetchOne(db)!
          )
        )
      }
      #expect(uuid.date == Date(staticISO8601: "2024-09-09T22:41:15+0000"))
    }

    @Test("Creates UUIDV7 From Valid UUIDV7 String")
    func createsUUIDV7FromString() async throws {
      @Dependency(\.defaultDatabase) var database

      let string = UUIDV7().uuidString
      let uuid = try await database.read { db in
        try #require(
          UUIDV7(
            uuidString: DummyRow.select { _ in
              SQLiteUUIDV7.toText(SQLiteUUIDV7.fromText(string))
            }.fetchOne(db)!
          )
        )
      }
      #expect(uuid.uuidString == string)
    }

    @Test("Fails to Create UUIDV7 From Valid UUIDV4 String")
    func failsToCreateUUIDV7FromUUIDV4String() async throws {
      @Dependency(\.defaultDatabase) var database

      let string = UUID().uuidString
      let isNull = try await database.read { db in
        try DummyRow.select { _ in
          SQLiteUUIDV7.fromText(string).is(SQLQueryExpression<UUIDV7?>("NULL"))
        }
        .fetchOne(db)!
      }
      #expect(isNull)
    }

    @Test("Fails to Create UUIDV7 From Random String")
    func failsToCreateUUIDV7FromRandomString() async throws {
      @Dependency(\.defaultDatabase) var database

      let isNull = try await database.read { db in
        try DummyRow.select { _ in
          SQLiteUUIDV7.fromText("blob").is(SQLQueryExpression<UUIDV7?>("NULL"))
        }
        .fetchOne(db)!
      }
      #expect(isNull)
    }

    @Test("Converts UUIDV7 To Lowercased String")
    func convertsUUIDV7ToLowercasedString() async throws {
      @Dependency(\.defaultDatabase) var database

      let uuidString = "1915c92e-b61e-7e3e-afea-2b5f3ea2dcf0"
      let uuid = try #require(UUIDV7(uuidString: uuidString))
      let string = try await database.read { db in
        try DummyRow.select { _ in SQLiteUUIDV7.toText(uuid) }.fetchOne(db)!
      }
      #expect(string == uuidString)
    }

    @Test("Converts UUIDV7 To Date")
    func convertsUUIDV7ToDate() async throws {
      @Dependency(\.defaultDatabase) var database

      let uuidDate = Date(staticISO8601: "2024-09-09T22:41:15+0000")
      let date = try await database.read { db in
        try DummyRow.select { _ in SQLiteUUIDV7.toDate(UUIDV7(uuidDate)) }.fetchOne(db)!
      }
      #expect(date == uuidDate)
    }

    @Test("Converts UUIDV7 To Unix Epoch")
    func convertsUUIDV7ToUnixEpoch() async throws {
      @Dependency(\.defaultDatabase) var database

      let uuidDate = Date(staticISO8601: "2024-09-09T22:41:15+0000")
      let timestamp = try await database.read { db in
        try DummyRow.select { _ in SQLiteUUIDV7.toUnixEpoch(UUIDV7(uuidDate)) }.fetchOne(db)!
      }
      #expect(timestamp == uuidDate.timeIntervalSince1970)
    }
  }

  extension DependencyValues {
    mutating func bootstrapDatabase() throws {
      var configuration = Configuration()
      configuration.prepareDatabase { db in
        db.addUUIDV7Functions()
      }
      let database = try SQLiteData.defaultDatabase(configuration: configuration)
      var migrator = DatabaseMigrator()
      migrator.registerMigration("Create dummy_rows") { db in
        try #sql(
          """
          CREATE TABLE "dummy_rows" (
            "uuid" BLOB NOT NULL
          ) STRICT
          """
        )
        .execute(db)
      }
      try migrator.migrate(database)
      try database.write { db in
        try DummyRow.insert {
          DummyRow(uuid: UUIDV7())
        }
        .execute(db)
      }
      defaultDatabase = database
    }
  }
#endif
