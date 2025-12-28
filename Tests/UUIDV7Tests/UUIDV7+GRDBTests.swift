#if SwiftUUIDV7GRDB
  import Foundation
  import GRDB
  import Testing
  import UUIDV7

  @Suite("UUIDV7+GRDB tests")
  struct UUIDV7GRDBTests {
    private let database: DatabaseQueue

    init() async throws {
      self.database = try DatabaseQueue()
      try await self.database.write { $0.addUUIDV7Functions() }
    }

    @Test("No Args Generates Random UUIDV7")
    func noArgsGeneratesRandomUUIDV7() async throws {
      let (uuid1, uuid2) = try await self.database.read { db in
        let uuid1 = try UUIDV7.fetchOne(db, sql: "SELECT uuidv7()")!
        let uuid2 = try UUIDV7.fetchOne(db, sql: "SELECT uuidv7()")!
        return (uuid1, uuid2)
      }
      #expect(uuid2 > uuid1)
    }

    @Test("Creates UUIDV7 From Date")
    func createsUUIDV7FromDate() async throws {
      let date = Date(staticISO8601: "2024-09-09T22:41:15+0000")
      let uuid = try await self.database.read { db in
        try UUIDV7.fetchOne(db, sql: "SELECT uuidv7_from_date(?)", arguments: [date])!
      }
      #expect(uuid.date == date)
    }

    @Test("Creates UUIDV7 From Time Interval")
    func createsUUIDV7FromTimeInterval() async throws {
      let date = Date(staticISO8601: "2024-09-09T22:41:15+0000")
      let uuid = try await self.database.read { db in
        try UUIDV7.fetchOne(
          db,
          sql: "SELECT uuidv7_from_date(?)",
          arguments: [date.timeIntervalSince1970]
        )!
      }
      #expect(uuid.date == date)
    }

    @Test("Creates UUIDV7 From Integer Time Interval")
    func createsUUIDV7FromIntegerTimeInterval() async throws {
      let date = Date(staticISO8601: "2024-09-09T22:41:15+0000")
      let uuid = try await self.database.read { db in
        try UUIDV7.fetchOne(
          db,
          sql: "SELECT uuidv7_from_date(?)",
          arguments: [Int(date.timeIntervalSince1970)]
        )!
      }
      #expect(uuid.date == date)
    }

    @Test("Creates UUIDV7 From Unix Epoch")
    func createsUUIDV7FromUnixEpoch() async throws {
      let date = Date(staticISO8601: "2024-09-09T22:41:15+0000")
      let uuid = try await self.database.read { db in
        try UUIDV7.fetchOne(
          db,
          sql: "SELECT uuidv7_from_unixepoch(?)",
          arguments: [date.timeIntervalSince1970]
        )!
      }
      #expect(uuid.date == date)
    }

    @Test("Creates UUIDV7 From Integer Unix Epoch")
    func createsUUIDV7FromIntegerUnixEpoch() async throws {
      let date = Date(staticISO8601: "2024-09-09T22:41:15+0000")
      let uuid = try await self.database.read { db in
        try UUIDV7.fetchOne(
          db,
          sql: "SELECT uuidv7_from_unixepoch(?)",
          arguments: [Int(date.timeIntervalSince1970)]
        )!
      }
      #expect(uuid.date == date)
    }

    @Test("Creates UUIDV7 From Date String")
    func createsUUIDV7FromDateString() async throws {
      let string: StaticString = "2024-09-09 22:41:15"
      let uuid = try await self.database.read { db in
        try UUIDV7.fetchOne(db, sql: "SELECT uuidv7_from_date(?)", arguments: [string.description])!
      }
      #expect(uuid.date == Date(staticISO8601: "2024-09-09T22:41:15+0000"))
    }

    @Test("Creates UUIDV7 From Valid UUIDV7 String")
    func createsUUIDV7FromString() async throws {
      let string = UUIDV7().uuidString
      let uuid = try await self.database.read { db in
        try UUIDV7.fetchOne(db, sql: "SELECT uuidv7_from_text(?)", arguments: [string])!
      }
      #expect(uuid.uuidString == string)
    }

    @Test("Fails to Create UUIDV7 From Valid UUIDV4 String")
    func failsToCreateUUIDV7FromUUIDV4String() async throws {
      let string = UUID().uuidString
      let uuid = try await self.database.read { db in
        try UUIDV7.fetchOne(db, sql: "SELECT uuidv7_from_text(?)", arguments: [string])
      }
      #expect(uuid == nil)
    }

    @Test("Fails to Create UUIDV7 From Random String")
    func failsToCreateUUIDV7FromRandomString() async throws {
      let uuid = try await self.database.read { db in
        try UUIDV7.fetchOne(db, sql: "SELECT uuidv7_from_text(?)", arguments: ["blob"])
      }
      #expect(uuid == nil)
    }

    @Test("Converts UUIDV7 To Lowercased String")
    func convertsUUIDV7ToLowercasedString() async throws {
      let uuidString = "1915c92e-b61e-7e3e-afea-2b5f3ea2dcf0"
      let uuid = try #require(UUIDV7(uuidString: uuidString))
      let string = try await self.database.read { db in
        try String.fetchOne(db, sql: "SELECT uuidv7_to_text(?)", arguments: [uuid])!
      }
      #expect(string == uuidString)
    }

    @Test("Converts UUIDV7 To Date")
    func convertsUUIDV7ToDate() async throws {
      let uuidDate = Date(staticISO8601: "2024-09-09T22:41:15+0000")
      let date = try await self.database.read { db in
        return try Date.fetchOne(
          db,
          sql: "SELECT uuidv7_to_date(?)",
          arguments: [UUIDV7(uuidDate)]
        )!
      }
      #expect(date == uuidDate)
    }

    @Test("Converts UUIDV7 To Unix Epoch")
    func convertsUUIDV7ToUnixEpoch() async throws {
      let uuidDate = Date(staticISO8601: "2024-09-09T22:41:15+0000")
      let timestamp = try await self.database.read { db in
        try TimeInterval.fetchOne(
          db,
          sql: "SELECT uuidv7_to_unixepoch(?)",
          arguments: [UUIDV7(uuidDate)]
        )!
      }
      #expect(timestamp == uuidDate.timeIntervalSince1970)
    }
  }
#endif
