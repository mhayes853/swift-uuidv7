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
  private let buffer: ManagedBuffer<State, PlatformLock.Primitive>

  init(_ initial: State) {
    self.buffer = LockedBuffer.create(minimumCapacity: 1) { buffer in
      buffer.withUnsafeMutablePointerToElements { PlatformLock.initialize($0) }
      return initial
    }
  }
}

extension Lock {
  private final class LockedBuffer: ManagedBuffer<State, PlatformLock.Primitive> {
    deinit {
      withUnsafeMutablePointerToElements { PlatformLock.deinitialize($0) }
    }
  }
}

extension Lock {
  func withLock<R>(_ critical: (inout State) throws -> sending R) rethrows -> R {
    try self.buffer.withUnsafeMutablePointers { header, lock in
      PlatformLock.lock(lock)
      defer { PlatformLock.unlock(lock) }
      return try critical(&header.pointee)
    }
  }
}

extension Lock: @unchecked Sendable where State: Sendable {}

// MARK: - PlatformLock

private enum PlatformLock {
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

  typealias Pointer = UnsafeMutablePointer<Primitive>

  static func initialize(_ platformLock: Pointer) {
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

  static func deinitialize(_ platformLock: Pointer) {
    #if canImport(Glibc) || canImport(Musl) || canImport(Bionic)
      let result = pthread_mutex_destroy(platformLock)
      precondition(result == 0, "pthread_mutex_destroy failed")
    #endif
    platformLock.deinitialize(count: 1)
  }

  static func lock(_ platformLock: Pointer) {
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

  static func unlock(_ platformLock: Pointer) {
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
}
