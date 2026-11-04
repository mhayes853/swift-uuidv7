import Testing

#if canImport(StandaloneUUIDV7)
  import StandaloneUUIDV7
#else
  import UUIDV7
#endif

@Suite
struct `UUIDV7 String Conversions tests` {
  @Test(arguments: 0..<16)
  func `Parses Legacy Optional Hyphens`(mask: Int) {
    var characters = Array("0191D85B8C4174459473A0B0C24B58A4".utf8)
    for (bit, offset) in [8, 13, 18, 23].enumerated() where mask & (1 << bit) != 0 {
      characters.insert(0x2D, at: offset)
    }
    let string = String(decoding: characters, as: UTF8.self)
    let expected = "0191D85B-8C41-7445-9473-A0B0C24B58A4"
    #expect(UUIDV7(uuidString: string)?.uuidString == expected)
    #expect(UUIDV7(uuidString: string.lowercased())?.uuidString == expected)
  }

  @Test(arguments: 0..<15)
  func `Validates Every ASCII Character In Legacy Formats`(mask: Int) {
    var original = Array("0191D85B8C4174459473A0B0C24B58A4".utf8)
    for (bit, offset) in [8, 13, 18, 23].enumerated() where mask & (1 << bit) != 0 {
      original.insert(0x2D, at: offset)
    }
    for position in original.indices {
      let digit = original[..<position].filter { $0 != 0x2D }.count
      for character in UInt8(0)...UInt8(127) {
        var characters = original
        characters[position] = character
        let isValid =
          if original[position] == 0x2D {
            character == 0x2D
          } else if digit == 12 {
            character == 0x37
          } else if digit == 16 {
            "89aAbB".utf8.contains(character)
          } else {
            "0123456789abcdefABCDEF".utf8.contains(character)
          }
        let string = String(decoding: characters, as: UTF8.self)
        #expect((UUIDV7(uuidString: string) != nil) == isValid)
      }
    }
  }

  @Test(arguments: [
    "0191D85B8C4174459473A0B0C24B58AG",
    "0191D85B8C4174459473A0B0C24B58A",
    "0191D85B8C4174459473A0B0C24B58A40",
    "0191D85B8C41-74459473A0B0C24B58A4",
    "0191D85B--8C4174459473A0B0C24B58A4",
    "0191D85B8C4144459473A0B0C24B58A4",
    "0191D85B8C417445C473A0B0C24B58A4"
  ])
  func `Rejects Invalid Legacy Strings`(string: String) {
    #expect(UUIDV7(uuidString: string) == nil)
  }

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
      let compact = hex.joined()
      for mask in 0..<15 {
        var characters = Array(compact.utf8)
        for (bit, offset) in [8, 13, 18, 23].enumerated() where mask & (1 << bit) != 0 {
          characters.insert(0x2D, at: offset)
        }
        let string = String(decoding: characters, as: UTF8.self)
        #expect(UUIDV7(uuidString: string) == uuid)
        #expect(UUIDV7(uuidString: string.lowercased()) == uuid)
      }
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
