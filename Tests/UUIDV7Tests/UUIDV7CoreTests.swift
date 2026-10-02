import Testing
import UUIDV7

@Suite
struct `UUIDV7 Core tests` {
  @Test
  func `Preserves Timestamp And Deterministic Bytes`() {
    let uuid = UUIDV7(timeIntervalSince1970: 1_000, 42)
    #expect(uuid.timeIntervalSince1970 == 1_000)
    #expect(uuid.uuidString == "0000000F-4240-7000-8000-00000000002A")
    #expect(UUIDV7(uuid: uuid.uuid) == uuid)
    #expect(UUIDV7(uuidString: uuid.uuidString.lowercased()) == uuid)
    #expect(UUIDVariant(uuid: uuid.uuid) == .rfc9562)
  }

  @Test(arguments: [
    "invalid",
    "00000000-0000-4000-8000-000000000000",
    "00000000-0000-7000-C000-000000000000"
  ])
  func `Rejects Invalid Strings Versions And Variants`(string: String) {
    #expect(UUIDV7(uuidString: string) == nil)
  }

  @Test
  func `Orders And Hashes UUIDs`() {
    let first = UUIDV7(timeIntervalSince1970: 1_000, 0)
    let second = UUIDV7(timeIntervalSince1970: 1_001, 0)
    #expect(first < second)
    #expect(Set([first, first, second]).count == 2)
  }

  @Test
  func `Generates Monotonically Increasing UUIDs`() {
    let uuids = (0..<10_000).map { _ in UUIDV7() }
    #expect(zip(uuids, uuids.dropFirst()).allSatisfy { $0 < $1 })
    #expect(uuids.allSatisfy { $0.timeIntervalSince1970 > 0 })
  }
}
