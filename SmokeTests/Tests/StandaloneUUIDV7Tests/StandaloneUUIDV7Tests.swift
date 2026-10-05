import Foundation
import StandaloneUUIDV7
import Testing

@Suite
struct `Standalone UUIDV7 tests` {
  @Test
  func `Foundation Support Is Enabled Automatically`() {
    let date = Date(timeIntervalSince1970: 1_000)
    let uuid = UUIDV7(date, 42)
    #expect(uuid.date == date)
    #expect(uuid.uuidString == "0000000F-4240-7000-8000-00000000002A")
    #expect(UUIDV7(uuid.rawValue) == uuid)
    #expect(UUIDV7(rawValue: uuid.rawValue) == uuid)
    #expect(uuid[dynamicMember: \UUID.uuidString] == uuid.rawValue.uuidString)
  }

  @Test
  func `Codable Interoperates With Foundation UUID`() throws {
    let uuid = UUIDV7(Date(timeIntervalSince1970: 1_000), 42)
    let encoded = try JSONEncoder().encode(uuid)
    #expect(try JSONDecoder().decode(UUID.self, from: encoded) == uuid.rawValue)
    let encodedUUID = try JSONEncoder().encode(uuid.rawValue)
    #expect(try JSONDecoder().decode(UUIDV7.self, from: encodedUUID) == uuid)
  }

  @Test
  func `Generates Monotonically Increasing Valid UUIDs`() {
    let first = UUIDV7()
    let second = UUIDV7()
    #expect(first < second)
    #expect(first.date.timeIntervalSince1970 > 0)
    #expect(UUIDVariant(uuid: first.uuid) == .rfc9562)
    #expect(UUIDV7(first.rawValue) == first)
    #expect(UUIDV7(uuidString: second.uuidString) == second)
    #expect(Set([first, first, second]).count == 2)
  }
}
