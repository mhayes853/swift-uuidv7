#ifndef UUIDV7_ASSEMBLY_H
#define UUIDV7_ASSEMBLY_H

#include <stdbool.h>
#include <stddef.h>

// NB: These functions are implemented in assembly by the .S files in this target, and are only
// declared on platforms that have an implementation. All other platforms use the portable Swift
// implementation.
#if (defined(__aarch64__) || defined(__x86_64__)) && defined(__LP64__) && !defined(_WIN32)

#pragma clang assume_nonnull begin

/// Writes the 36 byte uppercase hyphenated string representation of a 16 byte UUID.
///
/// Only call this when `uuidv7_is_supported` returns true.
void uuidv7_encode(const void *uuid, void *string);

/// Parses 32 case-insensitive hex digits, optionally separated by hyphens at string positions 8,
/// 13, 18, and 23, into 16 UUID bytes.
///
/// Returns false and leaves `uuid` untouched if the string is invalid. Only call this when
/// `uuidv7_is_supported` returns true.
bool uuidv7_decode(const void *_Nullable string, size_t length, void *uuid);

#if defined(__x86_64__)
// NB: Not every x86-64 CPU supports AVX2, so support is detected on first use and cached in
// uuidv7_cpu_support (0 until detected, then 1 when supported, and -1 otherwise). Concurrent first
// uses may both detect support, but they always store the same value.
__attribute__((visibility("hidden"))) extern signed char uuidv7_cpu_support;
__attribute__((visibility("hidden"))) bool uuidv7_detect_cpu_support(void);
#endif

/// Returns whether the CPU supports the instructions that `uuidv7_encode` and `uuidv7_decode` use.
static inline bool uuidv7_is_supported(void) {
#if defined(__x86_64__)
  signed char support = __atomic_load_n(&uuidv7_cpu_support, __ATOMIC_RELAXED);
  return support != 0 ? support > 0 : uuidv7_detect_cpu_support();
#else
  return true;
#endif
}

#pragma clang assume_nonnull end

#endif
#endif
