#if canImport(Foundation)
  import Foundation

  extension Date {
    init(staticISO8601: StaticString) {
      self = formatter.date(from: "\(staticISO8601)")!
    }
  }

  private nonisolated(unsafe) let formatter = ISO8601DateFormatter()
#endif
