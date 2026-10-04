#if SwiftUUIDV7Tagged
  import UUIDV7
  import Tagged
  #if SwiftUUIDV7Foundation
    import Foundation
  #endif
  import Testing

  @Suite("UUIDV7+Tagged tests")
  struct UUIDV7TaggedTests {
    @Test("Initialization")
    func initialization() {
      let uuid = Tagged<_TestTag, UUIDV7>()
      let uuid2 = Tagged<_TestTag, UUIDV7>()
      let uuid3 = Tagged<_TestTag, UUIDV7>.now
      #expect(uuid2 > uuid)
      #expect(uuid3 > uuid2)
    }

    @Test("From String Invalid")
    func fromStringInvalid() {
      let uuid = Tagged<_TestTag, UUIDV7>(uuidString: "00000000-0000-4000-8000-000000000000")
      #expect(uuid == nil)
    }

    @Test("From String Valid")
    func fromStringValid() {
      let string = UUIDV7().uuidString
      let uuid = Tagged<_TestTag, UUIDV7>(uuidString: string)
      #expect(uuid?.uuidString == string)
    }

    #if SwiftUUIDV7Foundation
      @Test("From Date")
      func fromDate() {
        let date = Date(staticISO8601: "2024-09-09T22:41:15+0000")
        let uuid = Tagged<_TestTag, UUIDV7>(date)
        #expect(uuid.date == date)
      }
    #endif
  }

  private enum _TestTag {}
#endif
