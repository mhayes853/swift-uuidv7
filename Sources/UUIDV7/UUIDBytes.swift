#if canImport(Foundation)
  import Foundation

  public typealias UUIDBytes = uuid_t
#else
  public typealias UUIDBytes = (
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
  )

  public typealias TimeInterval = Double
#endif
