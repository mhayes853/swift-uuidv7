import Foundation

#if canImport(WinSDK)
  import WinSDK
#elseif canImport(Android)
  import Android
#elseif os(WASI)
  import WASILibc
#endif

// MARK: - RandomUUIDBytesGenerator

struct RandomUUIDBytesGenerator {
  static nonisolated(unsafe) let shared = Lock(Self())

  private static let cacheSize = 256

  private var cache = UnsafeMutablePointer<uuid_t>.allocate(capacity: Self.cacheSize)
  private var cacheIndex = 0

  private init() {}
}

// MARK: - Next

extension RandomUUIDBytesGenerator {
  mutating func next() -> uuid_t {
    defer { self.cacheIndex = (self.cacheIndex + 1) % Self.cacheSize }
    if self.cacheIndex == 0 {
      self.readBytes()
    }
    return self.cache[self.cacheIndex]
  }
}

// MARK: - Read Bytes

extension RandomUUIDBytesGenerator {
  #if os(Windows)
    private func readBytes() {
      BCryptGenRandom(
        nil,
        self.cache,
        UInt32(MemoryLayout<uuid_t>.size * Self.cacheSize),
        UInt32(BCRYPT_RNG_USE_ENTROPY_IN_BUFFER | BCRYPT_USE_SYSTEM_PREFERRED_RNG)
      )
    }
  #elseif os(WASI)
    private func readBytes() {
      _ = __wasi_random_get(self.cache, __wasi_size_t(MemoryLayout<uuid_t>.size * Self.cacheSize))
    }
  #else
    private func readBytes() {
      let fd = open("/dev/urandom", O_RDONLY)
      read(fd, self.cache, MemoryLayout<uuid_t>.size * Self.cacheSize)
      close(fd)
    }
  #endif
}
