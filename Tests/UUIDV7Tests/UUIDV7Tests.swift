#if canImport(Foundation)
  import Foundation
  import Testing
  import UUIDV7

  @Suite("UUIDV7 tests")
  struct UUIDV7Tests {
    @Test(
      "From UUID Invalid",
      arguments: [
        UUID(),
        UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
        UUID(uuidString: "A123209E-52CB-4FE4-932F-DB30BAB742CB")!,
        UUID(uuidString: "1915C92E-B61E-4E3E-AFEA-2B5F3EA2DCF0")!,
        UUID(uuidString: "A123209E-52CB-7FE4-C32F-DB30BAB742CB")!,
        UUID(uuid: (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16))
      ]
    )
    func fromUUIDInvalid(uuid: UUID) async throws {
      #expect(UUIDV7(uuid) == nil)
    }

    @Test(
      "From UUID Valid",
      arguments: [
        UUID(uuidString: "1915C92E-B61E-7E3E-AFEA-2B5F3EA2DCF0")!,
        UUID(uuidString: "A123209E-52CB-7FE4-932F-DB30BAB742CB")!,
        UUID(uuidString: "00000000-0000-7000-A000-000000000000")!,
        UUID(uuid: (25, 21, 201, 46, 182, 30, 126, 62, 175, 234, 43, 95, 62, 162, 220, 240)),
        UUID(uuidString: "0191D85B-8C41-7445-9473-A0B0C24B58A4")!
      ]
    )
    func fromUUIDValid(uuid: UUID) async throws {
      #expect(UUIDV7(uuid)?.rawValue == uuid)
    }

    @Test(
      "From UUID String Invalid",
      arguments: [
        UUID().uuidString,
        "00000000-0000-0000-0000-000000000000",
        "A123209E-52CB-7FE4-C32F-DB30BAB742CB",
        "A123209E-52CB-4FE4-932F-DB30BAB742CB",
        "1915C92E-B61E-4E3E-AFEA-2B5F3EA2DCF0"
      ]
    )
    func fromUUIDStringInvalid(uuid: String) async throws {
      #expect(UUIDV7(uuidString: uuid) == nil)
    }

    @Test(
      "From UUID String Valid",
      arguments: [
        "1915C92E-B61E-7E3E-AFEA-2B5F3EA2DCF0",
        "A123209E-52CB-7FE4-932F-DB30BAB742CB",
        "00000000-0000-7000-A000-000000000000",
        "0191D85B-8C41-7445-9473-A0B0C24B58A4"
      ]
    )
    func fromUUIDStringValid(uuid: String) async throws {
      #expect(UUIDV7(uuidString: uuid)?.uuidString == uuid)
    }

    @Test(
      "From uuid_t Invalid",
      arguments: [
        UUID(uuid: UUID().uuid),
        UUID(uuid: (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16))
      ]
    )
    func fromUUIDTInvalid(uuid: UUID) async throws {
      #expect(UUIDV7(uuid: uuid.uuid) == nil)
    }

    @Test(
      "From uuid_t Valid",
      arguments: [
        UUID(uuid: (25, 21, 201, 46, 182, 30, 126, 62, 175, 234, 43, 95, 62, 162, 220, 240)),
        UUID(uuid: (161, 35, 32, 158, 82, 203, 127, 228, 147, 47, 219, 48, 186, 183, 66, 203))
      ]
    )
    func fromUUIDTValid(uuid: UUID) async throws {
      let uuid2 = try #require(UUIDV7(uuid: uuid.uuid)?.uuid)
      #expect(UUID(uuid: uuid2) == uuid)
    }

    @Test(
      "From Date",
      arguments: [
        (Date(staticISO8601: "2024-09-09T22:37:05+0000"), "0191D8EE-F668"),
        (Date(staticISO8601: "2024-09-09T22:41:15+0000"), "0191D8F2-C6F8"),
        (Date(staticISO8601: "2060-10-04T21:27:19+0000"), "029ADCB1-7ED8"),
        (Date(staticISO8601: "1993-05-20T10:40:43+0000"), "00ABCDEF-A7F8")
      ]
    )
    @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
    func fromDate(date: Date, prefix: String) async throws {
      let uuid = UUIDV7(date)
      #expect(uuid.uuidString.starts(with: prefix))
      let pattern = /^[0-9A-F]{8}-[0-9A-F]{4}-7[0-9A-F]{3}-[89AB][0-9A-F]{3}-[0-9A-F]{12}$/
      #expect(uuid.uuidString.wholeMatch(of: pattern) != nil)
    }

    @Test(
      "From Date and Deterministic Integer",
      arguments: [
        (0, "0191D8EE-F668-7000-8000-000000000000"),
        (1, "0191D8EE-F668-7000-8000-000000000001"),
        (10, "0191D8EE-F668-7000-8000-00000000000A"),
        (40, "0191D8EE-F668-7000-8000-000000000028"),
        (27822, "0191D8EE-F668-7000-8000-00000000AE6C")
      ]
    )
    func fromDateInteger(integer: UInt32, uuidString: String) async throws {
      let uuid = UUIDV7(Date(staticISO8601: "2024-09-09T22:37:05+0000"), integer)
      #expect(uuid == UUIDV7(uuidString: uuidString))
    }

    #if SWIFT_UUIDV7_EXIT_TESTABLE_PLATFORM && swift(>=6.2)
      @Test("Exits When Negative Timestamp Used")
      func exitNegativeTimestamp() async throws {
        await #expect(processExitsWith: .failure, "\(_negativeTimeStampMessage(-1000))") {
          _ = UUIDV7(timeIntervalSince1970: -1000)
        }
      }
    #endif

    @Test(
      "Stores Date",
      arguments: [
        Date(staticISO8601: "2024-09-09T22:37:05+0000"),
        Date(staticISO8601: "2024-09-09T22:41:15+0000"),
        Date(staticISO8601: "2060-10-04T21:27:19+0000"),
        Date(staticISO8601: "1993-05-20T10:40:43+0000")
      ]
    )
    func date(date: Date) async throws {
      let uuid = UUIDV7(date)
      #expect(uuid.date == date)
    }

    @Test("2 Random Instances are Not Equal")
    func randomNotEqual() async throws {
      for _ in 0..<10_000 {
        let (u1, u2) = (UUIDV7(), UUIDV7())
        #expect(u1 != u2)
      }
    }

    @Test("2 Same Dated Instances are Not Equal")
    func datedNotEqual() async throws {
      let date = Date()
      let (u1, u2) = (UUIDV7(date), UUIDV7(date))
      #expect(u1 != u2)
    }

    @Test("Comparable")
    func comparable() async throws {
      var u1 = UUIDV7(Date(staticISO8601: "2024-09-09T22:37:05+0000"))
      var u2 = UUIDV7(Date(staticISO8601: "2024-09-09T22:41:15+0000"))
      #expect(u2 > u1)
      #expect(u1 < u2)

      u2 = UUIDV7(Date(staticISO8601: "1993-05-20T10:40:43+0000"), 1000)
      #expect(u2 < u1)
      #expect(u1 > u2)

      u1 = UUIDV7(Date(staticISO8601: "1993-05-20T10:40:43+0000"), 1001)
      #expect(u2 < u1)
      #expect(u1 > u2)
    }

    @Test("Monotonically Increases when Generated Randomly")
    func monotonicallyIncreasing() async throws {
      var u1 = UUIDV7()
      for _ in 0..<10 {
        let u2 = UUIDV7()
        #expect(u2 > u1)
        #expect(u1 < u2)
        u1 = u2
      }
    }

    @Test("Monotonically Increases when System Time is Moved Backwards")
    func monotonicallyIncreasingWhenBackwards() async throws {
      let date = Date()
      let u1 = UUIDV7(systemNow: date)
      let u2 = UUIDV7(systemNow: date - 1000)
      let u3 = UUIDV7(systemNow: date - 2000)
      #expect(u3 > u2)
      #expect(u2 > u1)
      #expect(u1 < u2)
      #expect(u2 < u3)
    }

    @Test("Monotonically Increases when System Time Fluctuates")
    func monotonicallyIncreasingWhenFluctuating() async throws {
      let date = Date()
      var u1 = UUIDV7(systemNow: date)
      for i in 0..<1000 {
        let interval = TimeInterval(i.isMultiple(of: 2) ? -i : i)
        let u2 = UUIDV7(systemNow: date + interval)
        #expect(u2 > u1)
        #expect(u1 < u2)
        u1 = u2
      }
    }

    @Test("Monotonically Increases when Jump in System Time")
    func monotonicallyIncreasesWhenJump() async throws {
      let date = Date()
      var u1 = UUIDV7(systemNow: date)
      for i in 0..<1000 {
        let u2 = UUIDV7(systemNow: date - TimeInterval(i))
        #expect(u2 > u1)
        #expect(u1 < u2)
        u1 = u2
      }
      for i in 1000..<2000 {
        let u2 = UUIDV7(systemNow: date + TimeInterval(i))
        #expect(u2 > u1)
        #expect(u1 < u2)
        u1 = u2
      }
    }

    @Test("Decode Valid UUIDV7")
    func decodeValidUUID() throws {
      let u = UUID(uuidString: "1915C92E-B61E-7E3E-AFEA-2B5F3EA2DCF0")!
      let data = try JSONEncoder().encode(u)
      let u7 = try JSONDecoder().decode(UUIDV7.self, from: data)
      #expect(u7.rawValue == u)
    }

    @Test("Does not Decode Non-UUIDV7 UUID")
    func invalidDecodedUUID() throws {
      let u = UUID()
      let data = try JSONEncoder().encode(u)
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(UUIDV7.self, from: data)
      }
    }

    @Test("Does not Decode Invalid UUID Data")
    func invalidDecodedData() throws {
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(UUIDV7.self, from: Data())
      }
    }
  }
#endif
