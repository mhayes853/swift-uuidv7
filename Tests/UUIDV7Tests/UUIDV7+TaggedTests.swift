#if SwiftUUIDV7Tagged
  import UUIDV7
  import Tagged
  import Foundation
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
      let uuid = Tagged<_TestTag, UUIDV7>(uuidString: UUID().uuidString)
      #expect(uuid == nil)
    }

    @Test("From String Valid")
    func fromStringValid() {
      let string = UUIDV7().uuidString
      let uuid = Tagged<_TestTag, UUIDV7>(uuidString: string)
      #expect(uuid?.uuidString == string)
    }

    @Test("From Date")
    func fromDate() {
      let date = Date(staticISO8601: "2024-09-09T22:41:15+0000")
      let uuid = Tagged<_TestTag, UUIDV7>(date)
      #expect(uuid.date == date)
    }
  }

  private enum _TestTag {}
#endif
