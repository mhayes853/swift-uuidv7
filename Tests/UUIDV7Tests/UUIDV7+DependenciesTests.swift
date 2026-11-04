#if SwiftUUIDV7Dependencies
  import Testing
  import UUIDV7

  @Suite("UUIDV7+Dependencies tests")
  struct UUIDV7DependenciesTests {
    @Test
    func `Incrementing Generator Stays Unique And Ordered Across Byte Boundaries`() {
      let generator = UUIDV7Generator.incrementing(from: 0)
      let uuids = (0...65_536).map { _ in generator() }
      #expect(Set(uuids).count == uuids.count)
      #expect(zip(uuids, uuids.dropFirst()).allSatisfy { $0 < $1 })
      #expect(uuids[256].uuidString == "00000000-0000-7000-8000-000000000100")
      #expect(uuids[65_536].uuidString == "00000000-0000-7000-8000-000000010000")
    }

    @Test("Incrementing Generator")
    func incrementingGenerator() {
      let generator = UUIDV7Generator.incrementing(from: 0)
      let next = generator()
      let next2 = generator()
      let next3 = generator()
      let next4 = generator()

      #expect(next.uuidString == "00000000-0000-7000-8000-000000000000")
      #expect(next2.uuidString == "00000000-0000-7000-8000-000000000001")
      #expect(next3.uuidString == "00000000-0000-7000-8000-000000000002")
      #expect(next4.uuidString == "00000000-0000-7000-8000-000000000003")
    }
  }
#endif
