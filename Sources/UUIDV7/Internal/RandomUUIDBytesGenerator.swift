import Foundation

// MARK: - RandomUUIDBytesGenerator

struct RandomUUIDBytesGenerator {
  private static let cacheSize = 256
  static let shared = Lock(Self())

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
        NULL,
        self.cache,
        MemoryLayout<uuid_t>.size * Self.cacheSize,
        BCRYPT_RNG_USE_ENTROPY_IN_BUFFER | BCRYPT_USE_SYSTEM_PREFERRED_RNG
      )
    }
  #elseif os(WASI)
    private func readBytes() {
      getentropy(self.cache, MemoryLayout<uuid_t>.size * Self.cacheSize)
    }
  #else
    private func readBytes() {
      let fd = open("/dev/urandom", O_RDONLY)
      read(fd, self.cache, MemoryLayout<uuid_t>.size * Self.cacheSize)
      close(fd)
    }
  #endif
}
