#if SwiftUUIDV7StructuredQueries
  import Foundation
  import StructuredQueriesCore
  import StructuredQueriesSQLiteCore

  // MARK: - QueryBindable

  extension UUIDV7: QueryBindable {}

  // MARK: - BytesRepresentation

  extension UUIDV7 {
    /// A query expression representing a ``UUIDV7`` as bytes.
    ///
    /// ```swift
    /// @Table
    /// struct Item {
    ///   @Column(as: UUIDV7.BytesRepresentation.self)
    ///   let id: UUIDV7
    /// }
    ///
    /// Item.insert { $0.id } values: { UUIDV7() }
    /// // INSERT INTO "items" ("id") VALUES (<blob>)
    /// ```
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

    public init?(queryBinding: QueryBinding) {
      guard case .blob(let data) = queryBinding else { return nil }
      guard data.count == 16 else { return nil }
      let output = data.withUnsafeBytes { UUIDV7(uuid: $0.load(as: uuid_t.self)) }
      guard let output else { return nil }
      self.init(queryOutput: output)
    }
  }

  extension UUIDV7.BytesRepresentation: QueryDecodable {
    public init(decoder: inout some QueryDecoder) throws {
      let queryOutput = try [UInt8](decoder: &decoder)
      guard queryOutput.count == 16 else { throw InvalidBytes() }
      let output = queryOutput.withUnsafeBytes { UUIDV7(uuid: $0.load(as: uuid_t.self)) }
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
    /// A query expression representing a ``UUIDV7`` as a lowercased string.
    ///
    /// ```swift
    /// @Table
    /// struct Item {
    ///   @Column(as: UUIDV7.UppercasedRepresentation.self)
    ///   let id: UUIDV7
    /// }
    ///
    /// Item.insert { $0.id } values: { UUIDV7() }
    /// // INSERT INTO "items" ("id") VALUES ('1915C92E-B61E-7E3E-AFEA-2B5F3EA2DCF0')
    /// ```
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

    public init?(queryBinding: QueryBinding) {
      guard case .text(let uuidString) = queryBinding else { return nil }
      guard let uuid = UUIDV7(uuidString: uuidString) else { return nil }
      self.init(queryOutput: uuid)
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
