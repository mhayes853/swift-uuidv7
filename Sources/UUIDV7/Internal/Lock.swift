//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

#if canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#elseif canImport(Musl)
  import Musl
#elseif canImport(WinSDK)
  import WinSDK
#elseif canImport(Bionic)
  import Bionic
#elseif arch(wasm32)
#else
  #error("Unsupported platform")
#endif

// MARK: - Lock

struct Lock<State> {
  private final class LockedBuffer: ManagedBuffer<State, _Lock.Primitive> {
    deinit {
      withUnsafeMutablePointerToElements { _Lock.deinitialize($0) }
    }
  }

  private let buffer: ManagedBuffer<State, _Lock.Primitive>

  init(_ initial: State) {
    buffer = LockedBuffer.create(minimumCapacity: 1) { buffer in
      buffer.withUnsafeMutablePointerToElements { _Lock.initialize($0) }
      return initial
    }
  }

  func withLock<R>(_ critical: (inout State) throws -> R) rethrows -> R {
    try buffer.withUnsafeMutablePointers { header, lock in
      _Lock.lock(lock)
      defer { _Lock.unlock(lock) }
      return try critical(&header.pointee)
    }
  }
}

extension Lock: @unchecked Sendable {}

// MARK: - _Lock

private struct _Lock {
  #if canImport(Darwin)
    typealias Primitive = os_unfair_lock
  #elseif canImport(Glibc) || canImport(Musl) || canImport(Bionic)
    #if os(FreeBSD) || os(OpenBSD)
      // BSD libc does not annotate the nullability of pthread APIs.
      // We should replace this with the appropriate API note in the platform
      // overlay.
      // https://github.com/swiftlang/swift/issues/81407
      typealias Primitive = pthread_mutex_t?
    #else
      typealias Primitive = pthread_mutex_t
    #endif
  #elseif canImport(WinSDK)
    typealias Primitive = SRWLOCK
  #elseif arch(wasm32)
    typealias Primitive = Int
  #else
    #error("Unsupported platform")
  #endif

  typealias PlatformLock = UnsafeMutablePointer<Primitive>
  let platformLock: PlatformLock

  private init(_ platformLock: PlatformLock) {
    self.platformLock = platformLock
  }

  fileprivate static func initialize(_ platformLock: PlatformLock) {
    #if canImport(Darwin)
      platformLock.initialize(to: os_unfair_lock())
    #elseif canImport(Glibc) || canImport(Musl) || canImport(Bionic)
      let result = pthread_mutex_init(platformLock, nil)
      precondition(result == 0, "pthread_mutex_init failed")
    #elseif canImport(WinSDK)
      InitializeSRWLock(platformLock)
    #elseif arch(wasm32)
      platformLock.initialize(to: 0)
    #else
      #error("Unsupported platform")
    #endif
  }

  fileprivate static func deinitialize(_ platformLock: PlatformLock) {
    #if canImport(Glibc) || canImport(Musl) || canImport(Bionic)
      let result = pthread_mutex_destroy(platformLock)
      precondition(result == 0, "pthread_mutex_destroy failed")
    #endif
    platformLock.deinitialize(count: 1)
  }

  fileprivate static func lock(_ platformLock: PlatformLock) {
    #if canImport(Darwin)
      os_unfair_lock_lock(platformLock)
    #elseif canImport(Glibc) || canImport(Musl) || canImport(Bionic)
      pthread_mutex_lock(platformLock)
    #elseif canImport(WinSDK)
      AcquireSRWLockExclusive(platformLock)
    #elseif arch(wasm32)
    #else
      #error("Unsupported platform")
    #endif
  }

  fileprivate static func unlock(_ platformLock: PlatformLock) {
    #if canImport(Darwin)
      os_unfair_lock_unlock(platformLock)
    #elseif canImport(Glibc) || canImport(Musl) || canImport(Bionic)
      let result = pthread_mutex_unlock(platformLock)
      precondition(result == 0, "pthread_mutex_unlock failed")
    #elseif canImport(WinSDK)
      ReleaseSRWLockExclusive(platformLock)
    #elseif arch(wasm32)
    #else
      #error("Unsupported platform")
    #endif
  }

  static func allocate() -> _Lock {
    let platformLock = PlatformLock.allocate(capacity: 1)
    initialize(platformLock)
    return _Lock(platformLock)
  }

  func deinitialize() {
    _Lock.deinitialize(platformLock)
    platformLock.deallocate()
  }

  func lock() {
    _Lock.lock(platformLock)
  }

  func unlock() {
    _Lock.unlock(platformLock)
  }

  /// Acquire the lock for the duration of the given block.
  ///
  /// This convenience method should be preferred to `lock` and `unlock` in
  /// most situations, as it ensures that the lock will be released regardless
  /// of how `body` exits.
  ///
  /// - Parameter body: The block to execute while holding the lock.
  /// - Returns: The value returned by the block.
  func withLock<T>(_ body: () throws -> T) rethrows -> T {
    self.lock()
    defer {
      self.unlock()
    }
    return try body()
  }

  // specialise Void return (for performance)
  func withLockVoid(_ body: () throws -> Void) rethrows {
    try self.withLock(body)
  }
}
