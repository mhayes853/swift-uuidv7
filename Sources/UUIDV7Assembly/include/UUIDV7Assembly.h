#ifndef UUIDV7_ASSEMBLY_H
#define UUIDV7_ASSEMBLY_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

// NB: These functions are implemented in assembly by the .S files in this target, and are only
// declared on platforms that have an implementation. All other platforms use the portable Swift
// implementation.
#if defined(__aarch64__) && defined(__LP64__) && !defined(_WIN32)

#pragma clang assume_nonnull begin

/// The state of the 12-bit counter that guarantees monotonicity as outlined by section 6.2 of
/// RFC 9562.
typedef struct {
  uint64_t previous_timestamp;
  uint64_t offset;
  uint16_t sequence;
} uuidv7_monotonic_state;

/// Writes the 48-bit big-endian `unix_millis` timestamp, version, and variant into 16 random
/// bytes in place.
void uuidv7_apply_timestamp(void *uuid, uint64_t unix_millis);

/// Advances `state` with `unix_millis`, and then writes the resulting 48-bit big-endian timestamp,
/// 12-bit counter, version, and variant into 16 random bytes in place.
void uuidv7_apply_monotonic_timestamp(
  uuidv7_monotonic_state *state,
  void *uuid,
  uint64_t unix_millis
);

/// Writes the 36 byte uppercase hyphenated string representation of a 16 byte UUID.
void uuidv7_encode(const void *uuid, void *string);

/// Parses 32 case-insensitive hex digits, optionally separated by hyphens at string positions 8,
/// 13, 18, and 23, into 16 UUID bytes.
///
/// Returns false and leaves `uuid` untouched if the string is invalid.
bool uuidv7_decode(const void *_Nullable string, size_t length, void *uuid);

#pragma clang assume_nonnull end

#endif
#endif
