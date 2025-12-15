#if canImport(Foundation)
  import Foundation
  import Testing
  import UUIDV7

  @Suite("UUID+Extensions tests")
  struct UUIDExtensionsTests {
    @Test(
      "Version",
      arguments: [
        (UUID.nil, 0x00),
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
      ]
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
        (UUID.nil, UUIDVariant.ncs),
        (UUID.max, UUIDVariant.future)
      ]
    )
    func variant(uuid: UUID, variant: UUIDVariant) {
      #expect(uuid.variant == variant)
    }
  }
#endif
