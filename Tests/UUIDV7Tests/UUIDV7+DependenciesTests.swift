#if SwiftUUIDV7Dependencies
  import Testing
  import UUIDV7

  @Suite("UUIDV7+Dependencies tests")
  struct UUIDV7DependenciesTests {
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
