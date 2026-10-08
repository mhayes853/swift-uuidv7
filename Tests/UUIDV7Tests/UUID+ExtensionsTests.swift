#if SwiftUUIDV7Foundation && canImport(Foundation)
  import Foundation
  import Testing
  import UUIDV7

  @Suite("UUID+Extensions tests")
  struct UUIDExtensionsTests {
    @Test(
      "Version",
      arguments: [
        (UUID.min, 0x00),
        (UUID(uuidString: "000003e8-612d-11f0-9f00-325096b39f47")!, 0x01),
        (UUID(uuidString: "000003e8-612d-21f0-9f00-325096b39f47")!, 0x02),
        (UUID(uuidString: "000003e8-612d-31f0-9f00-325096b39f47")!, 0x03),
        (UUID(uuidString: "000003e8-612d-41f0-9f00-325096b39f47")!, 0x04),
        (UUID(uuidString: "000003e8-612d-51f0-9f00-325096b39f47")!, 0x05),
        (UUID(uuidString: "000003e8-612d-61f0-9f00-325096b39f47")!, 0x06),
        (UUID(uuidString: "000003e8-612d-71f0-9f00-325096b39f47")!, 0x07),
        (UUID(uuidString: "000003e8-612d-81f0-9f00-325096b39f47")!, 0x08),
        (UUID(uuidString: "000003e8-612d-91f0-9f00-325096b39f47")!, 0x09),
        (UUID(uuidString: "000003e8-612d-a1f0-9f00-325096b39f47")!, 0x0A),
        (UUID(uuidString: "000003e8-612d-b1f0-9f00-325096b39f47")!, 0x0B),
        (UUID(uuidString: "000003e8-612d-c1f0-9f00-325096b39f47")!, 0x0C),
        (UUID(uuidString: "000003e8-612d-d1f0-9f00-325096b39f47")!, 0x0D),
        (UUID(uuidString: "000003e8-612d-e1f0-9f00-325096b39f47")!, 0x0E),
        (UUID.max, 0x0F)
      ] as [(UUID, Int)]
    )
    func version(uuid: UUID, version: Int) {
      #expect(uuid.version == version)
    }

    @Test(
      "Variant",
      arguments: [
        (UUID(), UUIDVariant.rfc9562),
        (UUID(uuidString: "550e8400-e29b-41d4-a716-446655440000")!, UUIDVariant.rfc9562),
        (UUID(uuidString: "550e8400-e29b-41d4-a716-446655440000")!, UUIDVariant.rfc9562),
        (UUID(uuidString: "f9168c5e-ceb2-4faa-d6bf-329bf39fa1e4")!, UUIDVariant.microsoft),
        (UUID(uuidString: "f81d4fae-7dec-11d0-7765-00a0c91e6bf6")!, UUIDVariant.ncs),
        (UUID.min, UUIDVariant.ncs),
        (UUID.max, UUIDVariant.future)
      ]
    )
    func variant(uuid: UUID, variant: UUIDVariant) {
      #expect(UUIDVariant(uuid: uuid.uuid) == variant)
    }

    @Test("Min And Max")
    func minAndMax() {
      #expect(UUID.min.uuidString == "00000000-0000-0000-0000-000000000000")
      #expect(UUID.max.uuidString == "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")
    }

    @Test
    func `Setting The Version Only Changes The Version Bits`() {
      var uuid = UUID(uuidString: "0000000F-4240-7E95-A8EF-E333B266F103")!
      uuid.version = 4
      #expect(uuid.version == 4)
      #expect(uuid.uuidString == "0000000F-4240-4E95-A8EF-E333B266F103")
    }

    @Test
    func `Random With Seeded Generator`() {
      var generator = SplitMix64(seed: 42)
      let uuid = UUID.random(using: &generator)
      #expect(uuid.uuidString == "BDD73226-2FEB-4E95-A8EF-E333B266F103")
    }

    @Test
    func `Version 7 Uses The Current Time`() throws {
      let now = Date()
      let uuid = UUID.version7()
      #expect(uuid.version == 7)
      #expect(UUIDVariant(uuid: uuid.uuid) == .rfc9562)
      let date = try #require(uuid.date)
      // NB: Other tests can move the shared monotonic state forward, so only check the lower bound.
      #expect(date.timeIntervalSince(now) > -1)
    }

    @Test
    func `Version 7 At Date With Offset`() {
      var generator = SplitMix64(seed: 42)
      let date = Date(timeIntervalSince1970: 1_000)
      let u1 = UUID.version7(at: date, offset: .seconds(5))
      let u2 = UUID.version7(using: &generator, at: date, offset: .seconds(5))
      #expect(u1.date == Date(timeIntervalSince1970: 1_005))
      #expect(u2.date == Date(timeIntervalSince1970: 1_005))
    }

    @Test
    func `Version 7 Clamps Dates Before 1970`() {
      let u1 = UUID.version7(at: Date(timeIntervalSince1970: -1_000))
      let u2 = UUID.version7(at: Date(timeIntervalSince1970: 1_000), offset: .seconds(-2_000))
      #expect(u1.date == Date(timeIntervalSince1970: 0))
      #expect(u2.date == Date(timeIntervalSince1970: 0))
    }

    @Test(
      arguments: [
        ("0000000F-4240-7E95-A8EF-E333B266F103", 1_000),
        ("0000000F-4240-7E95-C8EF-E333B266F103", 1_000)
      ]
    )
    func `Date Of Version 7 UUID`(uuidString: String, timeInterval: TimeInterval) {
      let uuid = UUID(uuidString: uuidString)!
      #expect(uuid.date == Date(timeIntervalSince1970: timeInterval))
    }

    @Test
    func `Date Is Nil For Other Versions`() {
      #expect(UUID.version4().date == nil)
      #expect(UUID.min.date == nil)
      #expect(UUID.max.date == nil)
    }

    @Test
    func `Lowercased UUID String`() {
      let uuid = UUID(uuidString: "0000000F-4240-7E95-A8EF-E333B266F103")!
      #expect(uuid.lowercasedUUIDString == "0000000f-4240-7e95-a8ef-e333b266f103")
    }

    #if compiler(>=6.2)
      @Test
      func `From RawSpan`() {
        let uuid = UUID()
        let bytes = withUnsafeBytes(of: uuid.uuid) { [UInt8]($0) }
        #expect(UUID(copying: bytes.span.bytes) == uuid)
      }

      @Test
      func `Initializing With OutputRawSpan`() {
        let uuid = UUID()
        let output = UUID { output in
          withUnsafeBytes(of: uuid.uuid) { bytes in
            for byte in bytes {
              output.append(byte)
            }
          }
        }
        #expect(output == uuid)
      }
    #endif
  }
#endif
