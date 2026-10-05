import Testing
import UUIDV7

#if SwiftUUIDV7Foundation && canImport(Foundation)
  import Foundation
#endif

@Suite
struct `UUIDV7 tests` {
  @Test
  func `Preserves Timestamp And Deterministic Bytes`() {
    let uuid = UUIDV7(timeIntervalSince1970: 1_000, 42)
    #expect(uuid.timeIntervalSince1970 == 1_000)
    #expect(uuid.uuidString == "0000000F-4240-7000-8000-00000000002A")
    #expect(UUIDV7(uuid: uuid.uuid) == uuid)
    #expect(UUIDV7(uuidString: uuid.uuidString.lowercased()) == uuid)
    #expect(UUIDVariant(uuid: uuid.uuid) == .rfc9562)
  }

  @Test(
    arguments: [
      (0, "0000000F-4240-7000-8000-000000000000"),
      (1, "0000000F-4240-7000-8000-000000000001"),
      (10, "0000000F-4240-7000-8000-00000000000A"),
      (40, "0000000F-4240-7000-8000-000000000028"),
      (27822, "0000000F-4240-7000-8000-00000000AE6C"),
      (UInt32.max, "0000000F-4240-7000-8000-0000FFFFFFFF")
    ]
  )
  func `From Time Interval And Deterministic Integer`(integer: UInt32, uuidString: String) {
    let uuid = UUIDV7(timeIntervalSince1970: 1_000, integer)
    #expect(uuid.uuidString == uuidString)
    #expect(uuid == UUIDV7(uuidString: uuidString))
  }

  @Test(arguments: [0, 1, 1_000.5, 1_725_921_425, 2_000_000_000])
  func `Stores Time Interval With Millisecond Precision`(timeInterval: Double) {
    let uuid = UUIDV7(timeIntervalSince1970: timeInterval)
    #expect(uuid.timeIntervalSince1970 == timeInterval)
    #expect(UUIDVariant(uuid: uuid.uuid) == .rfc9562)
    #expect(uuid.uuid.6 >> 4 == 0x7)
  }

  @Test
  func `Same Time Interval And Integer Are Equal`() {
    let u1 = UUIDV7(timeIntervalSince1970: 1_000, 5)
    let u2 = UUIDV7(timeIntervalSince1970: 1_000, 5)
    #expect(u1 == u2)
    #expect(u1.hashValue == u2.hashValue)
  }

  @Test
  func `Same Time Interval With Random Bytes Is Not Equal`() {
    let u1 = UUIDV7(timeIntervalSince1970: 1_000)
    let u2 = UUIDV7(timeIntervalSince1970: 1_000)
    #expect(u1 != u2)
  }

  @Test
  func `Different Integers Are Not Equal`() {
    let u1 = UUIDV7(timeIntervalSince1970: 1_000, 5)
    let u2 = UUIDV7(timeIntervalSince1970: 1_000, 6)
    #expect(u1 != u2)
  }

  @Test(
    arguments: [
      "invalid",
      "",
      "00000000-0000-4000-8000-000000000000",
      "00000000-0000-7000-C000-000000000000",
      "00000000-0000-7000-8000-00000000000",
      "00000000-0000-7000-8000-0000000000000",
      "0000000000007000800000000000000000",
      "0000000G-0000-7000-8000-000000000000"
    ]
  )
  func `Rejects Invalid Strings Versions And Variants`(string: String) {
    #expect(UUIDV7(uuidString: string) == nil)
  }

  @Test(
    arguments: [
      "1915C92E-B61E-7E3E-AFEA-2B5F3EA2DCF0",
      "A123209E-52CB-7FE4-932F-DB30BAB742CB",
      "00000000-0000-7000-A000-000000000000",
      "0191D85B-8C41-7445-9473-A0B0C24B58A4"
    ]
  )
  func `Round Trips Valid UUID Strings`(string: String) {
    let uuid = UUIDV7(uuidString: string)
    #expect(uuid?.uuidString == string)
    #expect(uuid?.description == string)
    #expect(UUIDV7(uuidString: string.lowercased()) == uuid)
  }

  @Test(
    arguments: [
      "0191D85B8C4174459473A0B0C24B58A4",
      "0191D85B-8C4174459473A0B0C24B58A4",
      "0191D85B-8C41-74459473A0B0C24B58A4",
      "0191D85B-8C41-7445-9473A0B0C24B58A4",
      "0191d85b-8c41-7445-9473-a0b0c24b58a4",
      "0191d85b8c4174459473a0b0c24b58a4",
      "0191D85b-8c41-7445-9473-A0b0C24B58a4"
    ]
  )
  func `Parses UUID Strings With Optional Hyphens And Any Case`(string: String) {
    #expect(UUIDV7(uuidString: string)?.uuidString == "0191D85B-8C41-7445-9473-A0B0C24B58A4")
  }

  @Test(
    arguments: [
      "",
      "0191D85B-8C41-7445-9473-A0B0C24B58A",
      "0191D85B-8C41-7445-9473-A0B0C24B58A40",
      "0191D85B8C4174459473A0B0C24B58A",
      "0191D85B8C4174459473A0B0C24B58A4-",
      "-0191D85B8C4174459473A0B0C24B58A4",
      "0191D85-B8C41-7445-9473-A0B0C24B58A4",
      "0191D85B+8C41-7445-9473-A0B0C24B58A4",
      "0191D85B--8C41-7445-9473A0B0C24B58A4",
      "0191D85B-8C41-7445-9473-A0B0C24B58AG",
      "0191D85B-8C41-7445-9473-A0B0C24B58A:",
      "0191D85B-8C41-7445-9473-A0B0C24B58A@",
      "0191D85B-8C41-7445-9473-A0B0C24B58a`",
      "0191D85B-8C41-7445-9473-A0B0C24B58é",
      "0191D85B 8C41 7445 9473 A0B0C24B58A4"
    ]
  )
  func `Rejects Malformed UUID Strings`(string: String) {
    #expect(UUIDV7(uuidString: string) == nil)
  }

  @Test(
    arguments: [
      [UInt8](repeating: 0, count: 16),
      [UInt8](repeating: 0xFF, count: 16),
      [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
      [25, 21, 201, 46, 182, 30, 78, 62, 175, 234, 43, 95, 62, 162, 220, 240],
      [25, 21, 201, 46, 182, 30, 126, 62, 207, 234, 43, 95, 62, 162, 220, 240]
    ]
  )
  func `From Bytes Invalid`(bytes: [UInt8]) {
    #expect(UUIDV7(uuid: uuidBytes(bytes)) == nil)
  }

  @Test(
    arguments: [
      [25, 21, 201, 46, 182, 30, 126, 62, 175, 234, 43, 95, 62, 162, 220, 240],
      [161, 35, 32, 158, 82, 203, 127, 228, 147, 47, 219, 48, 186, 183, 66, 203],
      [0, 0, 0, 0, 0, 0, 0x70, 0, 0x80, 0, 0, 0, 0, 0, 0, 0]
    ] as [[UInt8]]
  )
  func `From Bytes Valid`(bytes: [UInt8]) throws {
    let uuid = try #require(UUIDV7(uuid: uuidBytes(bytes)))
    #expect(Array(withUnsafeBytes(of: uuid.uuid) { $0 }) == bytes)
  }

  @Test(
    arguments: [
      (0x00, UUIDVariant.ncs),
      (0x7F, UUIDVariant.ncs),
      (0x80, UUIDVariant.rfc9562),
      (0xBF, UUIDVariant.rfc9562),
      (0xC0, UUIDVariant.microsoft),
      (0xDF, UUIDVariant.microsoft),
      (0xE0, UUIDVariant.future),
      (0xFF, UUIDVariant.future)
    ] as [(UInt8, UUIDVariant)]
  )
  func `Variant`(byte: UInt8, variant: UUIDVariant) {
    var bytes = uuidBytes([UInt8](repeating: 0, count: 16))
    bytes.8 = byte
    #expect(UUIDVariant(uuid: bytes) == variant)
  }

  @Test(arguments: 0...15)
  func `Only Accepts Version 7`(version: Int) {
    var bytes = uuidBytes([UInt8](repeating: 0, count: 16))
    bytes.6 = UInt8(version) << 4
    bytes.8 = 0x80
    #expect((UUIDV7(uuid: bytes) != nil) == (version == 7))
  }

  @Test
  func `Orders And Hashes UUIDs`() {
    let first = UUIDV7(timeIntervalSince1970: 1_000, 0)
    let second = UUIDV7(timeIntervalSince1970: 1_001, 0)
    #expect(first < second)
    #expect(Set([first, first, second]).count == 2)
  }

  @Test
  func `Comparable`() {
    var u1 = UUIDV7(timeIntervalSince1970: 1_725_921_425)
    var u2 = UUIDV7(timeIntervalSince1970: 1_725_921_675)
    #expect(u2 > u1)
    #expect(u1 < u2)

    u2 = UUIDV7(timeIntervalSince1970: 737_894_443, 1000)
    #expect(u2 < u1)
    #expect(u1 > u2)

    u1 = UUIDV7(timeIntervalSince1970: 737_894_443, 1001)
    #expect(u2 < u1)
    #expect(u1 > u2)
  }

  @Test
  func `Generates Monotonically Increasing UUIDs`() {
    let uuids = (0..<10_000).map { _ in UUIDV7() }
    #expect(zip(uuids, uuids.dropFirst()).allSatisfy { $0 < $1 })
    #expect(uuids.allSatisfy { $0.timeIntervalSince1970 > 0 })
  }

  @Test
  func `Generated UUIDs Are Unique`() {
    let uuids = (0..<10_000).map { _ in UUIDV7() }
    #expect(Set(uuids).count == uuids.count)
  }

  @Test
  func `Generated UUIDs Are Valid UUIDV7s`() {
    let uuid = UUIDV7()
    #expect(UUIDV7(uuid: uuid.uuid) == uuid)
    #expect(UUIDV7(uuidString: uuid.uuidString) == uuid)
    #expect(UUIDVariant(uuid: uuid.uuid) == .rfc9562)
    #expect(uuid.uuid.6 >> 4 == 0x7)
  }

  @Test
  func `Now Is Monotonically Increasing`() {
    let u1 = UUIDV7.now
    let u2 = UUIDV7.now
    #expect(u2 > u1)
  }

  @Test
  func `Monotonically Increases When System Time Is Moved Backwards`() {
    let now = UUIDV7().timeIntervalSince1970
    let u1 = UUIDV7(_systemNow: now)
    let u2 = UUIDV7(_systemNow: now - 1000)
    let u3 = UUIDV7(_systemNow: now - 2000)
    #expect(u2 > u1)
    #expect(u3 > u2)
  }

  @Test
  func `Monotonically Increases When System Time Fluctuates`() {
    let now = UUIDV7().timeIntervalSince1970
    var u1 = UUIDV7(_systemNow: now)
    for i in 0..<1000 {
      let interval = Double(i.isMultiple(of: 2) ? -i : i)
      let u2 = UUIDV7(_systemNow: now + interval)
      #expect(u2 > u1)
      u1 = u2
    }
  }

  @Test
  func `Monotonically Increases When System Time Jumps`() {
    let now = UUIDV7().timeIntervalSince1970
    var u1 = UUIDV7(_systemNow: now)
    for i in 0..<1000 {
      let u2 = UUIDV7(_systemNow: now - Double(i))
      #expect(u2 > u1)
      u1 = u2
    }
    for i in 1000..<2000 {
      let u2 = UUIDV7(_systemNow: now + Double(i))
      #expect(u2 > u1)
      u1 = u2
    }
  }

  @Test
  func `Monotonically Increases When System Time Is Frozen`() {
    let now = UUIDV7().timeIntervalSince1970
    // NB: More calls than the 12 bit counter can hold, so the counter rolls into the timestamp.
    var u1 = UUIDV7(_systemNow: now)
    for _ in 0..<10_000 {
      let u2 = UUIDV7(_systemNow: now)
      #expect(u2 > u1)
      u1 = u2
    }
  }

  @Test
  func `Negative Time Interval Message Mentions The Timestamp`() {
    let message = _negativeTimeStampMessage(-1000)
    #expect(message.contains("before January 1, 1970"))
  }

  #if SWIFT_UUIDV7_EXIT_TESTABLE_PLATFORM && swift(>=6.2)
    @Test
    func `Exits When Negative Timestamp Used`() async {
      await #expect(processExitsWith: .failure, "\(_negativeTimeStampMessage(-1000))") {
        _ = UUIDV7(timeIntervalSince1970: -1000)
      }
    }
  #endif

  #if SwiftUUIDV7Foundation && canImport(Foundation)
    @Test(
      arguments: [
        UUID(),
        UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
        UUID(uuidString: "A123209E-52CB-4FE4-932F-DB30BAB742CB")!,
        UUID(uuidString: "1915C92E-B61E-4E3E-AFEA-2B5F3EA2DCF0")!,
        UUID(uuidString: "A123209E-52CB-7FE4-C32F-DB30BAB742CB")!,
        UUID(uuid: (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16))
      ]
    )
    func `From UUID Invalid`(uuid: UUID) async throws {
      #expect(UUIDV7(uuid) == nil)
    }

    @Test(
      arguments: [
        UUID(uuidString: "1915C92E-B61E-7E3E-AFEA-2B5F3EA2DCF0")!,
        UUID(uuidString: "A123209E-52CB-7FE4-932F-DB30BAB742CB")!,
        UUID(uuidString: "00000000-0000-7000-A000-000000000000")!,
        UUID(uuid: (25, 21, 201, 46, 182, 30, 126, 62, 175, 234, 43, 95, 62, 162, 220, 240)),
        UUID(uuidString: "0191D85B-8C41-7445-9473-A0B0C24B58A4")!
      ]
    )
    func `From UUID Valid`(uuid: UUID) async throws {
      #expect(UUIDV7(uuid)?.rawValue == uuid)
    }

    @Test(
      arguments: [
        (Date(staticISO8601: "2024-09-09T22:37:05+0000"), "0191D8EE-F668"),
        (Date(staticISO8601: "2024-09-09T22:41:15+0000"), "0191D8F2-C6F8"),
        (Date(staticISO8601: "2060-10-04T21:27:19+0000"), "029ADCB1-7ED8"),
        (Date(staticISO8601: "1993-05-20T10:40:43+0000"), "00ABCDEF-A7F8")
      ]
    )
    @available(iOS 16, macOS 13, tvOS 16, watchOS 9, *)
    func `From Date`(date: Date, prefix: String) async throws {
      let uuid = UUIDV7(date)
      #expect(uuid.uuidString.starts(with: prefix))
      let pattern = /^[0-9A-F]{8}-[0-9A-F]{4}-7[0-9A-F]{3}-[89AB][0-9A-F]{3}-[0-9A-F]{12}$/
      #expect(uuid.uuidString.wholeMatch(of: pattern) != nil)
    }

    @Test(
      arguments: [
        (0, "0191D8EE-F668-7000-8000-000000000000"),
        (1, "0191D8EE-F668-7000-8000-000000000001"),
        (10, "0191D8EE-F668-7000-8000-00000000000A"),
        (40, "0191D8EE-F668-7000-8000-000000000028"),
        (27822, "0191D8EE-F668-7000-8000-00000000AE6C")
      ]
    )
    func `From Date And Deterministic Integer`(integer: UInt32, uuidString: String) async throws {
      let uuid = UUIDV7(Date(staticISO8601: "2024-09-09T22:37:05+0000"), integer)
      #expect(uuid == UUIDV7(uuidString: uuidString))
    }

    @Test(
      arguments: [
        Date(staticISO8601: "2024-09-09T22:37:05+0000"),
        Date(staticISO8601: "2024-09-09T22:41:15+0000"),
        Date(staticISO8601: "2060-10-04T21:27:19+0000"),
        Date(staticISO8601: "1993-05-20T10:40:43+0000")
      ]
    )
    func `Stores Date`(date: Date) async throws {
      let uuid = UUIDV7(date)
      #expect(uuid.date == date)
    }

    @Test
    func `Decode Valid UUIDV7`() throws {
      let u = UUID(uuidString: "1915C92E-B61E-7E3E-AFEA-2B5F3EA2DCF0")!
      let data = try JSONEncoder().encode(u)
      let u7 = try JSONDecoder().decode(UUIDV7.self, from: data)
      #expect(u7.rawValue == u)
    }

    @Test
    func `Does Not Decode Non-UUIDV7 UUID`() throws {
      let u = UUID()
      let data = try JSONEncoder().encode(u)
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(UUIDV7.self, from: data)
      }
    }

    @Test
    func `Does Not Decode Invalid UUID Data`() throws {
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(UUIDV7.self, from: Data())
      }
    }
  #endif
}

private func uuidBytes(_ bytes: [UInt8]) -> UUIDBytes {
  (
    bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
    bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
  )
}
