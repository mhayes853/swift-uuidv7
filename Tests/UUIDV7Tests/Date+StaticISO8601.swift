#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension Date {
    init(staticISO8601: StaticString) {
        self = try! Date(staticISO8601.description, strategy: .iso8601)
    }
}
