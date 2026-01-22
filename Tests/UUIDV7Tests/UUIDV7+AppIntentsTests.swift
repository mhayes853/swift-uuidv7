#if canImport(AppIntents)
import UUIDV7
import AppIntents
import Testing

@Suite("UUIDV7+AppIntents tests")
struct UUIDV7AppIntentsTests {
    @Test(
        "EntityIdentifierString",
        arguments: [
            "01980C7E-9BB3-736D-8396-66646250B62B",
            "01980C7F-91FE-7867-95D5-7F87FD25FE67",
            "01980C7F-B814-717D-B320-C7BC7B2D0C75"
        ]
    )
    func entityIdentifierString(string: String) throws {
        let uuid = try #require(UUIDV7(uuidString: string))
        #expect(uuid.entityIdentifierString == string)
    }
    
    @Test(
        "EntityIdentifier For String",
        arguments: [
            "01980C7E-9BB3-736D-8396-66646250B62B",
            "01980C7F-91FE-7867-95D5-7F87FD25FE67",
            "01980C7F-B814-717D-B320-C7BC7B2D0C75"
        ]
    )
    func entityIdentifierForString(string: String) throws {
        let uuid = try #require(UUIDV7.entityIdentifier(for: string))
        #expect(uuid.uuidString == string)
    }
}
#endif
