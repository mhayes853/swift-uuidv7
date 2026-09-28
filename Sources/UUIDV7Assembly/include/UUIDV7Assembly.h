#ifndef UUIDV7_ASSEMBLY_H
#define UUIDV7_ASSEMBLY_H

#include <stdbool.h>
#include <stddef.h>

// NB: These functions are implemented in assembly by the .S files in this target, and are only
// declared on platforms that have an implementation. All other platforms use the portable Swift
// implementation.
#if defined(__aarch64__) && defined(__LP64__) && !defined(_WIN32)

#pragma clang assume_nonnull begin

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
