#if SwiftUUIDV7StructuredQueries
  import Foundation
  import StructuredQueriesCore

  // MARK: - QueryBindable

  extension UUIDV7: QueryBindable {}

  // MARK: - BytesRepresentation

  extension UUIDV7 {
    public struct BytesRepresentation: QueryRepresentable {
      public var queryOutput: UUIDV7

      public init(queryOutput: UUIDV7) {
        self.queryOutput = queryOutput
      }
    }
  }

  extension Optional where Wrapped == UUIDV7 {
    public typealias BytesRepresentation = UUIDV7.BytesRepresentation?
  }

  extension UUIDV7.BytesRepresentation: QueryBindable {
    public var queryBinding: QueryBinding {
      .blob(withUnsafeBytes(of: queryOutput.uuid, [UInt8].init))
    }
  }

  extension UUIDV7.BytesRepresentation: QueryDecodable {
    public init(decoder: inout some QueryDecoder) throws {
      let queryOutput = try [UInt8](decoder: &decoder)
      guard queryOutput.count == 16 else { throw InvalidBytes() }
      let output = queryOutput.withUnsafeBytes {
        UUIDV7(uuid: $0.load(as: uuid_t.self))
      }
      guard let output else { throw InvalidBytes() }
      self.init(queryOutput: output)
    }

    private struct InvalidBytes: Error {}
  }

  extension UUIDV7.BytesRepresentation: SQLiteType {
    public static var typeAffinity: SQLiteTypeAffinity {
      [UInt8].typeAffinity
    }
  }

  // MARK: - UppercaseRepresentation

  extension UUIDV7 {
    public struct UppercaseRepresentation: QueryRepresentable {
      public var queryOutput: UUIDV7

      public init(queryOutput: UUIDV7) {
        self.queryOutput = queryOutput
      }
    }
  }

  extension Optional where Wrapped == UUIDV7 {
    public typealias UppercaseRepresentation = UUIDV7.UppercaseRepresentation?
  }

  extension UUIDV7.UppercaseRepresentation: QueryBindable {
    public var queryBinding: QueryBinding {
      .text(self.queryOutput.uuidString.uppercased())
    }
  }

  extension UUIDV7.UppercaseRepresentation: QueryDecodable {
    public init(decoder: inout some QueryDecoder) throws {
      guard let uuid = try UUIDV7(uuidString: String(decoder: &decoder)) else {
        throw InvalidString()
      }
      self.init(queryOutput: uuid)
    }

    private struct InvalidString: Error {}
  }

  extension UUIDV7.UppercaseRepresentation: SQLiteType {
    public static var typeAffinity: SQLiteTypeAffinity {
      String.typeAffinity
    }
  }
#endif
