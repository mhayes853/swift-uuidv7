#if SwiftUUIDV7StructuredQueries
  import Foundation
  import StructuredQueriesCore
  import Testing
  import UUIDV7

  @Suite("UUIDV7+StructuredQueries tests")
  struct UUIDV7StructuredQueriesTests {
    @Test("Bytes Binding")
    func bytesBinding() throws {
      let uuid = try #require(
        UUIDV7(uuid: (25, 21, 201, 46, 182, 30, 126, 62, 175, 234, 43, 95, 62, 162, 220, 240))
      )
      #expect(
        UUIDV7.BytesRepresentation(queryOutput: uuid).queryBinding
          == .blob([25, 21, 201, 46, 182, 30, 126, 62, 175, 234, 43, 95, 62, 162, 220, 240])
      )
    }

    @Test(
      "Bytes Representation From QueryBinding",
      arguments: [
        (
          QueryBinding.blob([
            25, 21, 201, 46, 182, 30, 126, 62, 175, 234, 43, 95, 62, 162, 220, 240
          ]),
          UUIDV7(uuid: (25, 21, 201, 46, 182, 30, 126, 62, 175, 234, 43, 95, 62, 162, 220, 240))
        ),
        (
          QueryBinding.blob([
            25, 21, 201, 46, 182, 30, 126, 62, 175, 234
          ]),
          nil
        ),
        (
          QueryBinding.text("01990e14-53fe-7406-8bde-9bdc29d8d298"),
          nil
        )
      ]
    )
    func bytesRepresentationFromQueryBinding(
      binding: QueryBinding,
      expected: UUIDV7?
    ) throws {
      #expect(UUIDV7.BytesRepresentation(queryBinding: binding).queryOutput == expected)
    }

    @Test("Decodes From Valid UUID Bytes")
    func decodesFromValidUUIDBytes() throws {
      var decoder = TestQueryDecoder()
      let uuid = try #require(
        UUIDV7(uuid: (25, 21, 201, 46, 182, 30, 126, 62, 175, 234, 43, 95, 62, 162, 220, 240))
      )
      decoder.bytes = [25, 21, 201, 46, 182, 30, 126, 62, 175, 234, 43, 95, 62, 162, 220, 240]
      let representation = try UUIDV7.BytesRepresentation(decoder: &decoder)
      #expect(representation.queryOutput == uuid)
    }

    @Test("Fails To Decode From No Bytes")
    func failsToDecodeFromBytes() throws {
      var decoder = TestQueryDecoder()
      #expect(throws: Error.self) {
        try UUIDV7.BytesRepresentation(decoder: &decoder)
      }
    }

    @Test("Fails To Decode From Invalid UUID Bytes")
    func failsToDecodeFromInvalidUUIDBytes() throws {
      var decoder = TestQueryDecoder()
      decoder.bytes = [0, 0, 0, 0]
      #expect(throws: Error.self) {
        try UUIDV7.BytesRepresentation(decoder: &decoder)
      }
    }

    @Test("Uppercase Binding")
    func uppercaseBinding() throws {
      let uuid = try #require(UUIDV7(uuidString: "01980cba-8171-71d3-b174-5e348cb790d6"))
      #expect(
        UUIDV7.UppercaseRepresentation(queryOutput: uuid).queryBinding
          == .text("01980CBA-8171-71D3-B174-5E348CB790D6")
      )
    }

    @Test(
      "Uppercase Representation From QueryBinding",
      arguments: [
        (
          QueryBinding.blob([
            25, 21, 201, 46, 182, 30, 126, 62, 175, 234, 43, 95, 62, 162, 220, 240
          ]),
          nil
        ),
        (
          QueryBinding.text("01990E14-53FE-7406-8BDE-9BDC29D8D298"),
          UUIDV7(uuidString: "01990E14-53FE-7406-8BDE-9BDC29D8D298")
        )
      ]
    )
    func uppercaseRepresentationFromQueryBinding(
      binding: QueryBinding,
      expected: UUIDV7?
    ) throws {
      #expect(UUIDV7.UppercaseRepresentation(queryBinding: binding).queryOutput == expected)
    }

    @Test("Decodes From Valid UUID String")
    func decodesFromValidUUIDString() throws {
      var decoder = TestQueryDecoder()
      let uuid = try #require(UUIDV7(uuidString: "01980CBA-8171-71D3-B174-5E348CB790D6"))
      decoder.string = uuid.uuidString
      let representation = try UUIDV7.UppercaseRepresentation(decoder: &decoder)
      #expect(representation.queryOutput == uuid)
    }

    @Test("Fails to Decode From Invalid String")
    func failsToDecodeFromInvalidString() throws {
      var decoder = TestQueryDecoder()
      decoder.string = "invalid-string"
      #expect(throws: Error.self) {
        try UUIDV7.UppercaseRepresentation(decoder: &decoder)
      }
    }

    @Test("Fails to Decode From Invalid UUID String")
    func failsToDecodeFromInvalidUUIDString() throws {
      var decoder = TestQueryDecoder()
      decoder.string = UUID().uuidString
      #expect(throws: Error.self) {
        try UUIDV7.UppercaseRepresentation(decoder: &decoder)
      }
    }

    @Test("Fails to Decode From No String")
    func failsToDecodeFromNoString() throws {
      var decoder = TestQueryDecoder()
      #expect(throws: Error.self) {
        try UUIDV7.UppercaseRepresentation(decoder: &decoder)
      }
    }
  }

  private struct TestQueryDecoder: QueryDecoder {
    var bytes: [UInt8]?
    var string: String?

    func decode(_ columnType: String.Type) throws -> String? {
      self.string
    }

    func decode(_ columnType: [UInt8].Type) throws -> [UInt8]? {
      self.bytes
    }
  }
#endif
