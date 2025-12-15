#if canImport(Foundation)
  import Foundation
#endif

// MARK: - MonotonicityState

/// See https://www.rfc-editor.org/rfc/rfc9562.html#section-6.2-5.1
struct MonotonicityState: Sendable {
  static let current = Lock(MonotonicityState())

  private var previousTimestamp = UInt64(0)
  private var sequence = UInt16(0)
  private var offset = UInt64(0)

  private init() {}
}

// MARK: - NextMillisWithSequence

extension MonotonicityState {
  mutating func nextMillisWithSequence(
    timeIntervalSince1970 timeInterval: TimeInterval
  ) -> (UInt64, UInt16) {
    var currentMillis = UInt64(timeInterval * 1000) &+ self.offset
    if self.previousTimestamp == currentMillis {
      self.sequence &+= 1
    } else if currentMillis < self.previousTimestamp {
      self.sequence &+= 1
      self.offset = self.previousTimestamp - currentMillis
      currentMillis = self.previousTimestamp
    } else {
      self.offset = 0
      self.sequence = 0
    }
    if self.sequence > 0xFFF {
      self.sequence = 0
      currentMillis &+= 1
    }
    self.previousTimestamp = currentMillis
    return (currentMillis, self.sequence)
  }
}
