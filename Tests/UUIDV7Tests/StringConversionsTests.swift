import Testing

#if canImport(StandaloneUUIDV7)
  import StandaloneUUIDV7
#else
  import UUIDV7
#endif

@Suite
struct `UUIDV7 String Conversions tests` {
  @Test(arguments: 0..<16)
  func `Preserves Every Byte At Every Position`(position: Int) throws {
    let digits = Array("0123456789ABCDEF")
    for value in UInt8.min...UInt8.max {
      var bytes: [UInt8] = [
        0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0x7D, 0xEF,
        0x90, 0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC, 0xDE
      ]
      bytes[position] = value
      bytes[6] = (bytes[6] & 0x0F) | 0x70
      bytes[8] = (bytes[8] & 0x3F) | 0x80
      let uuidBytes = bytes.withUnsafeBytes { $0.loadUnaligned(as: UUIDBytes.self) }
      let uuid = try #require(UUIDV7(uuid: uuidBytes))
      let hex = bytes.map { String([digits[Int($0 >> 4)], digits[Int($0 & 0x0F)]]) }
      let expected = [
        hex[0..<4].joined(), hex[4..<6].joined(), hex[6..<8].joined(),
        hex[8..<10].joined(), hex[10..<16].joined()
      ]
      .joined(separator: "-")
      #expect(uuid.uuidString == expected)
      #expect(uuid.lowercasedUUIDString == expected.lowercased())
      #expect(UUIDV7(uuidString: expected) == uuid)
      #expect(UUIDV7(uuidString: expected.lowercased()) == uuid)
    }
  }

  @Test(arguments: 0..<36)
  func `Validates Every ASCII Character At Every Position`(position: Int) {
    let original = Array("0191D85B-8c41-7445-9473-A0B0C24B58a4".utf8)
    for character in UInt8(0)...UInt8(127) {
      var characters = original
      characters[position] = character
      let isValid =
        if [8, 13, 18, 23].contains(position) {
          character == 0x2D
        } else if position == 14 {
          character == 0x37
        } else if position == 19 {
          "89aAbB".utf8.contains(character)
        } else {
          "0123456789abcdefABCDEF".utf8.contains(character)
        }
      let string = String(decoding: characters, as: UTF8.self)
      #expect((UUIDV7(uuidString: string) != nil) == isValid)
    }
  }
}
