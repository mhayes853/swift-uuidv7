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
    let now = UUIDV7._platformTimeIntervalSince1970()
    let u1 = UUIDV7(_systemNow: now)
    let u2 = UUIDV7(_systemNow: now - 1000)
    let u3 = UUIDV7(_systemNow: now - 2000)
    #expect(u2 > u1)
    #expect(u3 > u2)
  }

  @Test
  func `Monotonically Increases When System Time Fluctuates`() {
    let now = UUIDV7._platformTimeIntervalSince1970()
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
    let now = UUIDV7._platformTimeIntervalSince1970()
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
    let now = UUIDV7._platformTimeIntervalSince1970()
    // NB: More calls than the 12 bit counter can hold, so the counter rolls into the timestamp.
    var u1 = UUIDV7(_systemNow: now)
    for _ in 0..<10_000 {
      let u2 = UUIDV7(_systemNow: now)
      #expect(u2 > u1)
      u1 = u2
    }
  }

  @Test
  func `Lowercased UUID String`() {
    let uuid = UUIDV7(timeIntervalSince1970: 1_000, 42)
    #expect(uuid.lowercasedUUIDString == "0000000f-4240-7000-8000-00000000002a")
    #expect(UUIDV7(uuidString: uuid.lowercasedUUIDString) == uuid)
  }

  @Test
  func `Min And Max`() {
    #expect(UUIDV7.min.uuidString == "00000000-0000-7000-8000-000000000000")
    #expect(UUIDV7.max.uuidString == "FFFFFFFF-FFFF-7FFF-BFFF-FFFFFFFFFFFF")
  }

  @Test(
    arguments: [
      (1_000, Duration.seconds(5), 1_005),
      (1_000, .milliseconds(250), 1_000.25),
      (1_000, .seconds(-500), 500),
      (1_000, .zero, 1_000)
    ] as [(TimeInterval, Duration, TimeInterval)]
  )
  func `Time Interval With Offset`(
    timeInterval: TimeInterval,
    offset: Duration,
    expected: TimeInterval
  ) {
    let uuid = UUIDV7(timeIntervalSince1970: timeInterval, offset: offset)
    #expect(uuid.timeIntervalSince1970 == expected)
  }

  @Test
  func `Offset Is Applied To The Current Time`() {
    let before = UUIDV7().timeIntervalSince1970
    let uuid = UUIDV7(offset: .seconds(-3_600))
    let after = UUIDV7().timeIntervalSince1970
    #expect(uuid.timeIntervalSince1970 >= before - 3_600)
    #expect(uuid.timeIntervalSince1970 <= after - 3_600)
  }

  @Test
  func `UUIDs With The Same Offset Are Monotonically Increasing`() {
    let now = UUIDV7._platformTimeIntervalSince1970()
    var u1 = UUIDV7(_systemNow: now, offset: .seconds(-60))
    for i in 0..<1000 {
      let interval = Double(i.isMultiple(of: 2) ? -i : i)
      let u2 = UUIDV7(_systemNow: now + interval, offset: .seconds(-60))
      #expect(u2 > u1)
      u1 = u2
    }
  }

  @Test
  func `Same Time Interval And Seeded Generator Are Equal`() {
    var g1 = SplitMix64(seed: 42)
    var g2 = SplitMix64(seed: 42)
    let u1 = UUIDV7(timeIntervalSince1970: 1_000, using: &g1)
    let u2 = UUIDV7(timeIntervalSince1970: 1_000, using: &g2)
    #expect(u1 == u2)
    #expect(u1.uuidString == "0000000F-4240-7E95-A8EF-E333B266F103")
  }

  @Test
  func `Different Seeded Generators Are Not Equal`() {
    var g1 = SplitMix64(seed: 42)
    var g2 = SplitMix64(seed: 43)
    let u1 = UUIDV7(timeIntervalSince1970: 1_000, using: &g1)
    let u2 = UUIDV7(timeIntervalSince1970: 1_000, using: &g2)
    #expect(u1 != u2)
  }

  @Test
  func `Time Interval With Generator And Offset`() {
    var generator = SplitMix64(seed: 42)
    let uuid = UUIDV7(timeIntervalSince1970: 1_000, using: &generator, offset: .seconds(5))
    #expect(uuid.timeIntervalSince1970 == 1_005)
  }

  @Test
  func `Generator UUIDs Are Monotonically Increasing Valid UUIDV7s`() {
    var generator = SplitMix64(seed: 42)
    let uuids = (0..<10_000).map { _ in UUIDV7(using: &generator) }
    #expect(zip(uuids, uuids.dropFirst()).allSatisfy { $0 < $1 })
    #expect(uuids.allSatisfy { UUIDV7(uuid: $0.uuid) == $0 })
  }

  @Test
  func `Constant Generator UUIDs Are Monotonically Increasing`() {
    var generator = ConstantGenerator()
    let uuids = (0..<10_000).map { _ in UUIDV7(using: &generator) }
    #expect(zip(uuids, uuids.dropFirst()).allSatisfy { $0 < $1 })
  }

  #if compiler(>=6.2)
    @Test
    func `From RawSpan Valid`() throws {
      let uuid = UUIDV7()
      let bytes = withUnsafeBytes(of: uuid.uuid) { [UInt8]($0) }
      #expect(UUIDV7(copying: bytes.span.bytes) == uuid)
    }

    @Test
    func `From RawSpan Invalid`() {
      let bytes = [UInt8](repeating: 0, count: 16)
      #expect(UUIDV7(copying: bytes.span.bytes) == nil)
    }

    @Test
    func `Initializing With OutputRawSpan`() {
      let uuid = UUIDV7(timeIntervalSince1970: 1_000, 42)
      let output = UUIDV7 { output in
        withUnsafeBytes(of: uuid.uuid) { bytes in
          for byte in bytes {
            output.append(byte)
          }
        }
      }
      #expect(output == uuid)
    }

    @Test
    func `Initializing With OutputRawSpan Invalid Version`() {
      let output = UUIDV7 { output in
        for _ in 0..<16 {
          output.append(UInt8(0))
        }
      }
      #expect(output == nil)
    }

    @Test
    func `Initializing With OutputRawSpan Rethrows Typed Error`() {
      struct SomeError: Error {}
      #expect(throws: SomeError.self) {
        try UUIDV7 { (_: inout OutputRawSpan) throws(SomeError) in throw SomeError() }
      }
    }
  #endif

  // NB: Spans are read outside of #expect, because Swift 6.2 can crash when compiling them inside.
  #if compiler(>=6.2) && hasFeature(Lifetimes) && hasFeature(AddressableTypes) && hasFeature(BuiltinModule)
    @Test
    func `Bytes Matches UUID Bytes`() {
      let uuid = UUIDV7(timeIntervalSince1970: 1_000, 42)
      let expected = withUnsafeBytes(of: uuid.uuid) { [UInt8]($0) }
      let bytes = byteArray(uuid.bytes)
      #expect(bytes == expected)
    }

    @Test
    func `Bytes Of UUIDs In An Array`() {
      let uuids = (0..<8).map { UUIDV7(timeIntervalSince1970: 1_000, UInt32($0)) }
      let expected = uuids.map { uuid in withUnsafeBytes(of: uuid.uuid) { [UInt8]($0) } }
      let bytes = uuids.map { byteArray($0.bytes) }
      #expect(bytes == expected)
    }

    @Test
    func `From Bytes Round Trips`() {
      let uuid = UUIDV7()
      let copy = UUIDV7(copying: uuid.bytes)
      #expect(copy == uuid)
    }

    @Test
    func `Reading Mutable Bytes`() {
      let uuid = UUIDV7(timeIntervalSince1970: 1_000, 42)
      let byteCount = uuid.mutableBytes.byteCount
      let bytes = byteArray(uuid.mutableBytes.bytes)
      let expected = byteArray(uuid.bytes)
      #expect(byteCount == 16)
      #expect(bytes == expected)
    }

    @Test
    func `Mutating Bytes In Place`() {
      var uuid = UUIDV7(timeIntervalSince1970: 1_000, 42)
      uuid.mutableBytes.storeBytes(of: 0xAB, toByteOffset: 15, as: UInt8.self)
      #expect(uuid.uuid.15 == 0xAB)
      #expect(uuid.timeIntervalSince1970 == 1_000)
    }

    @Test
    func `Mutating Bytes Through An Inout Parameter`() {
      func overwriteRandomBytes(_ bytes: inout MutableRawSpan) {
        for offset in 10..<16 {
          bytes.storeBytes(of: 0xCD, toByteOffset: offset, as: UInt8.self)
        }
      }
      var uuid = UUIDV7(timeIntervalSince1970: 1_000, 42)
      overwriteRandomBytes(&uuid.mutableBytes)
      #expect(uuid.uuidString.hasSuffix("CDCDCDCDCDCD"))
      #expect(UUIDV7(uuid: uuid.uuid) == uuid)
    }

    @Test
    func `Mutating Bytes Rethrows Errors`() {
      struct SomeError: Error {}
      func fail(_ bytes: inout MutableRawSpan) throws(SomeError) {
        bytes.storeBytes(of: 0xEF, toByteOffset: 15, as: UInt8.self)
        throw SomeError()
      }
      var uuid = UUIDV7(timeIntervalSince1970: 1_000, 42)
      #expect(throws: SomeError.self) {
        try fail(&uuid.mutableBytes)
      }
      #expect(uuid.uuid.15 == 0xEF)
    }

    private func byteArray(_ bytes: RawSpan) -> [UInt8] {
      bytes.withUnsafeBytes { [UInt8]($0) }
    }
  #endif

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

    @Test
    func `Offset Does Not Shift Subsequent UUIDs`() async {
      // NB: Runs in a separate process so that other tests cannot move the shared monotonic state.
      await #expect(processExitsWith: .success) {
        let now = UUIDV7._platformTimeIntervalSince1970()
        _ = UUIDV7(_systemNow: now, offset: .seconds(-86_400))
        _ = UUIDV7(_systemNow: now, offset: .seconds(86_400))
        let uuid = UUIDV7(_systemNow: now)
        precondition(abs(uuid.timeIntervalSince1970 - now) < 1)
      }
    }

    @Test
    func `Exits When Offset Produces Negative Timestamp`() async {
      await #expect(processExitsWith: .failure) {
        _ = UUIDV7(timeIntervalSince1970: 1_000, offset: .seconds(-2_000))
      }
      await #expect(processExitsWith: .failure) {
        _ = UUIDV7(offset: .seconds(-Int64.max / 1_000))
      }
    }

    @Test
    func `Exits When RawSpan Is Not 16 Bytes`() async {
      await #expect(processExitsWith: .failure) {
        let bytes = [UInt8](repeating: 0, count: 15)
        _ = UUIDV7(copying: bytes.span.bytes)
      }
    }

    @Test
    func `Exits When OutputRawSpan Is Not Fully Initialized`() async {
      await #expect(processExitsWith: .failure) {
        _ = UUIDV7 { $0.append(UInt8(0)) }
      }
    }

    #if hasFeature(Lifetimes) && hasFeature(AddressableTypes) && hasFeature(BuiltinModule)
      @Test
      func `Exits When Mutated Bytes Change The Version`() async {
        await #expect(processExitsWith: .failure) {
          var uuid = UUIDV7()
          uuid.mutableBytes.storeBytes(of: 0x40, toByteOffset: 6, as: UInt8.self)
        }
      }

      @Test
      func `Exits When Mutated Bytes Change The Variant`() async {
        await #expect(processExitsWith: .failure) {
          var uuid = UUIDV7()
          uuid.mutableBytes.storeBytes(of: 0xC0, toByteOffset: 8, as: UInt8.self)
        }
      }

      @Test
      func `Exits When Mutated Bytes Are Invalid And An Error Is Thrown`() async {
        await #expect(processExitsWith: .failure) {
          struct SomeError: Error {}
          func fail(_ bytes: inout MutableRawSpan) throws(SomeError) {
            bytes.storeBytes(of: 0x40, toByteOffset: 6, as: UInt8.self)
            throw SomeError()
          }
          var uuid = UUIDV7()
          try? fail(&uuid.mutableBytes)
        }
      }
    #endif
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
    func `Date With Offset`() {
      let date = Date(staticISO8601: "2024-09-09T22:37:05+0000")
      let uuid = UUIDV7(date, offset: .seconds(60))
      #expect(uuid.date == date.addingTimeInterval(60))
    }

    @Test
    func `Same Date And Seeded Generator Are Equal`() {
      let date = Date(staticISO8601: "2024-09-09T22:37:05+0000")
      var g1 = SplitMix64(seed: 42)
      var g2 = SplitMix64(seed: 42)
      let u1 = UUIDV7(date, using: &g1, offset: .seconds(60))
      let u2 = UUIDV7(date, using: &g2, offset: .seconds(60))
      #expect(u1 == u2)
      #expect(u1.date == date.addingTimeInterval(60))
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

private struct SplitMix64: RandomNumberGenerator, Hashable, Sendable {
  private var state: UInt64

  init(seed: UInt64) {
    self.state = seed
  }

  mutating func next() -> UInt64 {
    self.state &+= 0x9E37_79B9_7F4A_7C15
    var z = self.state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }
}

private struct ConstantGenerator: RandomNumberGenerator, Hashable, Sendable {
  func next() -> UInt64 {
    0
  }
}
