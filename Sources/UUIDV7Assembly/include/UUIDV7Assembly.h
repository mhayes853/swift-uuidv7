#ifndef UUIDV7_ASSEMBLY_H
#define UUIDV7_ASSEMBLY_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

// NB: These functions are only declared on platforms that have a SIMD implementation. All other
// platforms use the portable Swift implementation.
//
// 64-bit ARM implements them with NEON intrinsics in this header, so that Swift can inline them.
// x86-64 implements them in assembly (uuidv7_x86_64.S).
#if (defined(__aarch64__) || defined(__x86_64__)) && defined(__LP64__) && !defined(_WIN32)

#if defined(__aarch64__)
  #include <arm_neon.h>
  #include <string.h>
#endif

#pragma clang assume_nonnull begin

// MARK: - Interface

// NB: UUIDs are passed by value rather than through pointers. When Swift passes pointers to its
// local variables, it adds stack protector checks to the calling function, which measurably slow
// down the inlined NEON implementation.

/// The 16 bytes of a UUID in memory order, stored as 2 words so that they're passed in registers.
typedef struct {
  uint64_t words[2];
} uuidv7_bytes;

/// The result of `uuidv7_decode`, where `bytes` is only meaningful when `is_valid` is true.
typedef struct {
  uuidv7_bytes bytes;
  bool is_valid;
} uuidv7_decode_result;

/// Returns whether the CPU supports the instructions that `uuidv7_encode` and `uuidv7_decode` use.
static inline bool uuidv7_is_supported(void);

/// Writes the 36 byte uppercase hyphenated string representation of a UUID.
///
/// Only call this when `uuidv7_is_supported` returns true.
static inline void uuidv7_encode(uuidv7_bytes uuid, void *string);

/// Parses 32 case-insensitive hex digits, optionally separated by hyphens at string positions 8,
/// 13, 18, and 23, into the bytes of a UUID.
///
/// This accepts exactly what the portable Swift implementation accepts, so valid strings are 32-36
/// bytes long, and have exactly (length - 32) hyphens. Only call this when `uuidv7_is_supported`
/// returns true.
static inline uuidv7_decode_result uuidv7_decode(const void *_Nullable string, size_t length);

#if defined(__aarch64__)

// MARK: - 64-bit ARM

static inline bool uuidv7_is_supported(void) {
  return true;
}

static inline void uuidv7_encode(uuidv7_bytes uuid, void *string) {
  const uint8x16_t hex_digits = {
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'
  };
  // Shuffles of the hex digits, where index k is the high nibble digit of byte k, and index 16 + k
  // is its low nibble digit. Out of range indices leave hyphens in place.
  const uint8x16_t shuffle_0_16 = {
    0, 16, 1, 17, 2, 18, 3, 19, 0xFF, 4, 20, 5, 21, 0xFF, 6, 22
  };
  const uint8x16_t shuffle_16_32 = {
    7, 23, 0xFF, 8, 24, 9, 25, 0xFF, 10, 26, 11, 27, 12, 28, 13, 29
  };
  const uint8x16_t shuffle_32_36 = {14, 30, 15, 31};

  uint64x2_t words = vcombine_u64(vcreate_u64(uuid.words[0]), vcreate_u64(uuid.words[1]));
  uint8x16_t bytes = vreinterpretq_u8_u64(words);
  uint8x16x2_t digits = {{
    vqtbl1q_u8(hex_digits, vshrq_n_u8(bytes, 4)),
    vqtbl1q_u8(hex_digits, vandq_u8(bytes, vdupq_n_u8(0x0F)))
  }};

  uint8x16_t hyphens = vdupq_n_u8('-');
  uint8_t *characters = string;
  vst1q_u8(characters, vqtbx2q_u8(hyphens, digits, shuffle_0_16));
  vst1q_u8(characters + 16, vqtbx2q_u8(hyphens, digits, shuffle_16_32));
  uint32_t tail = vgetq_lane_u32(vreinterpretq_u32_u8(vqtbl2q_u8(digits, shuffle_32_36)), 0);
  memcpy(characters + 32, &tail, 4);
}

static inline uuidv7_decode_result uuidv7_decode(const void *_Nullable string, size_t length) {
  const uuidv7_decode_result invalid = {{{0, 0}}, false};
  const uint8_t *characters = string;
  const uint8x16_t hyphen = vdupq_n_u8('-');
  // The string positions that may hold hyphens. (Out of range indices are ignored.)
  const uint8x16_t hyphen_positions = {
    8, 13, 18, 23, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF
  };

  // The characters of the high and low nibble digits, and 0xFF in lanes that are otherwise valid.
  uint8x16_t high, low, valid;
  if (length == 36) {
    // The canonical layout gathers its digits with fixed indices, which keeps data dependent loads
    // off of its critical path. Indices 32-35 are string[32..<36].
    const uint8x16_t high_indices = {0, 2, 4, 6, 9, 11, 14, 16, 19, 21, 24, 26, 28, 30, 32, 34};
    const uint8x16_t low_indices = {1, 3, 5, 7, 10, 12, 15, 17, 20, 22, 25, 27, 29, 31, 33, 35};
    uint32_t tail;
    memcpy(&tail, characters + 32, 4);
    uint8x16x3_t string_0_36 = {{
      vld1q_u8(characters),
      vld1q_u8(characters + 16),
      vreinterpretq_u8_u32(vsetq_lane_u32(tail, vdupq_n_u32(0), 0))
    }};
    high = vqtbl3q_u8(string_0_36, high_indices);
    low = vqtbl3q_u8(string_0_36, low_indices);

    uint8x16x2_t string_0_32 = {{string_0_36.val[0], string_0_36.val[1]}};
    valid = vceqq_u8(vqtbx2q_u8(hyphen, string_0_32, hyphen_positions), hyphen);
  } else {
    if (length - 32 > 3) return invalid;  // length < 32 || length > 35

    // The expected string length for each hyphen mask (32 + the number of hyphens).
    static const uint8_t lengths[16] = {
      32, 33, 33, 34, 33, 34, 34, 35, 33, 34, 34, 35, 34, 35, 35, 36
    };
    // For each hyphen mask, the gather indices of the high nibble digits followed by the low nibble
    // digits. Indices 0-31 are string[0..<32], and indices 32-47 are the last 16 characters.
    static const uint8_t gather_indices[16][32] = {
      { 0,  2,  4,  6,  8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30,   // 0b0000
        1,  3,  5,  7,  9, 11, 13, 15, 17, 19, 21, 23, 25, 27, 29, 31},
      { 0,  2,  4,  6,  9, 11, 13, 15, 17, 19, 21, 23, 25, 27, 29, 31,   // 0b0001
        1,  3,  5,  7, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 47},
      { 0,  2,  4,  6,  8, 10, 12, 15, 17, 19, 21, 23, 25, 27, 29, 31,   // 0b0010
        1,  3,  5,  7,  9, 11, 14, 16, 18, 20, 22, 24, 26, 28, 30, 47},
      { 0,  2,  4,  6,  9, 11, 14, 16, 18, 20, 22, 24, 26, 28, 30, 46,   // 0b0011
        1,  3,  5,  7, 10, 12, 15, 17, 19, 21, 23, 25, 27, 29, 31, 47},
      { 0,  2,  4,  6,  8, 10, 12, 14, 16, 19, 21, 23, 25, 27, 29, 31,   // 0b0100
        1,  3,  5,  7,  9, 11, 13, 15, 17, 20, 22, 24, 26, 28, 30, 47},
      { 0,  2,  4,  6,  9, 11, 13, 15, 17, 20, 22, 24, 26, 28, 30, 46,   // 0b0101
        1,  3,  5,  7, 10, 12, 14, 16, 19, 21, 23, 25, 27, 29, 31, 47},
      { 0,  2,  4,  6,  8, 10, 12, 15, 17, 20, 22, 24, 26, 28, 30, 46,   // 0b0110
        1,  3,  5,  7,  9, 11, 14, 16, 19, 21, 23, 25, 27, 29, 31, 47},
      { 0,  2,  4,  6,  9, 11, 14, 16, 19, 21, 23, 25, 27, 29, 31, 46,   // 0b0111
        1,  3,  5,  7, 10, 12, 15, 17, 20, 22, 24, 26, 28, 30, 45, 47},
      { 0,  2,  4,  6,  8, 10, 12, 14, 16, 18, 20, 22, 25, 27, 29, 31,   // 0b1000
        1,  3,  5,  7,  9, 11, 13, 15, 17, 19, 21, 24, 26, 28, 30, 47},
      { 0,  2,  4,  6,  9, 11, 13, 15, 17, 19, 21, 24, 26, 28, 30, 46,   // 0b1001
        1,  3,  5,  7, 10, 12, 14, 16, 18, 20, 22, 25, 27, 29, 31, 47},
      { 0,  2,  4,  6,  8, 10, 12, 15, 17, 19, 21, 24, 26, 28, 30, 46,   // 0b1010
        1,  3,  5,  7,  9, 11, 14, 16, 18, 20, 22, 25, 27, 29, 31, 47},
      { 0,  2,  4,  6,  9, 11, 14, 16, 18, 20, 22, 25, 27, 29, 31, 46,   // 0b1011
        1,  3,  5,  7, 10, 12, 15, 17, 19, 21, 24, 26, 28, 30, 45, 47},
      { 0,  2,  4,  6,  8, 10, 12, 14, 16, 19, 21, 24, 26, 28, 30, 46,   // 0b1100
        1,  3,  5,  7,  9, 11, 13, 15, 17, 20, 22, 25, 27, 29, 31, 47},
      { 0,  2,  4,  6,  9, 11, 13, 15, 17, 20, 22, 25, 27, 29, 31, 46,   // 0b1101
        1,  3,  5,  7, 10, 12, 14, 16, 19, 21, 24, 26, 28, 30, 45, 47},
      { 0,  2,  4,  6,  8, 10, 12, 15, 17, 20, 22, 25, 27, 29, 31, 46,   // 0b1110
        1,  3,  5,  7,  9, 11, 14, 16, 19, 21, 24, 26, 28, 30, 45, 47},
      { 0,  2,  4,  6,  9, 11, 14, 16, 19, 21, 24, 26, 28, 30, 44, 46,   // 0b1111
        1,  3,  5,  7, 10, 12, 15, 17, 20, 22, 25, 27, 29, 31, 45, 47}
    };
    // The bit of each hyphen position in the hyphen mask.
    const uint8x16_t hyphen_bits = {1, 2, 4, 8};

    uint8x16x3_t string_0_32_and_last_16 = {{
      vld1q_u8(characters),
      vld1q_u8(characters + 16),
      vld1q_u8(characters + length - 16)
    }};
    uint8x16x2_t string_0_32 = {{string_0_32_and_last_16.val[0], string_0_32_and_last_16.val[1]}};

    // The hyphens must account for every byte beyond the 32 hex digits.
    uint8x16_t hyphens = vceqq_u8(vqtbl2q_u8(string_0_32, hyphen_positions), hyphen);
    uint8_t mask = vaddvq_u8(vandq_u8(hyphens, hyphen_bits));
    if (lengths[mask] != length) return invalid;

    // Gather the digits of the layout. Hyphens anywhere else then fail the digit check.
    high = vqtbl3q_u8(string_0_32_and_last_16, vld1q_u8(gather_indices[mask]));
    low = vqtbl3q_u8(string_0_32_and_last_16, vld1q_u8(gather_indices[mask] + 16));
    valid = vdupq_n_u8(0xFF);
  }

  // A character is a hex digit when the classes of its high and low nibbles intersect. Bit 0 is 0-9
  // (0x3_), bit 1 is A-F and a-f (0x4_ and 0x6_), and the upper nibble of a high nibble class is
  // the offset of a letter's value from its low nibble.
  const uint8x16_t high_nibble_classes = {0x00, 0x00, 0x00, 0x01, 0x92, 0x00, 0x92};
  const uint8x16_t low_nibble_classes = {
    0x01, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x01, 0x01, 0x01
  };
  const uint8x16_t low_nibble = vdupq_n_u8(0x0F);
  uint8x16_t high_classes = vqtbl1q_u8(high_nibble_classes, vshrq_n_u8(high, 4));
  uint8x16_t low_classes = vqtbl1q_u8(high_nibble_classes, vshrq_n_u8(low, 4));
  uint8x16_t high_values = vandq_u8(high, low_nibble);
  uint8x16_t low_values = vandq_u8(low, low_nibble);
  valid = vandq_u8(valid, vtstq_u8(high_classes, vqtbl1q_u8(low_nibble_classes, high_values)));
  valid = vandq_u8(valid, vtstq_u8(low_classes, vqtbl1q_u8(low_nibble_classes, low_values)));

  // Every lane must be valid. (shrn packs the 16 lane masks into 64 bits.)
  uint8x8_t valid_bits = vshrn_n_u16(vreinterpretq_u16_u8(valid), 4);
  if (vget_lane_u64(vreinterpret_u64_u8(valid_bits), 0) != UINT64_MAX) return invalid;

  high_values = vsraq_n_u8(high_values, high_classes, 4);
  low_values = vsraq_n_u8(low_values, low_classes, 4);
  uint64x2_t words = vreinterpretq_u64_u8(vsliq_n_u8(low_values, high_values, 4));
  uuidv7_decode_result result = {{{vgetq_lane_u64(words, 0), vgetq_lane_u64(words, 1)}}, true};
  return result;
}

#else

// MARK: - x86-64

// NB: Not every x86-64 CPU supports AVX2, so support is detected on first use and cached in
// uuidv7_cpu_support (0 until detected, then 1 when supported, and -1 otherwise). Concurrent first
// uses may both detect support, but they always store the same value.
__attribute__((visibility("hidden"))) extern signed char uuidv7_cpu_support;
__attribute__((visibility("hidden"))) bool uuidv7_detect_cpu_support(void);

// NB: The assembly implementations read and write UUIDs through pointers.
__attribute__((visibility("hidden"))) void uuidv7_avx2_encode(const void *uuid, void *string);
__attribute__((visibility("hidden"))) bool uuidv7_avx2_decode(
  const void *_Nullable string,
  size_t length,
  void *uuid
);

static inline bool uuidv7_is_supported(void) {
  signed char support = __atomic_load_n(&uuidv7_cpu_support, __ATOMIC_RELAXED);
  return support != 0 ? support > 0 : uuidv7_detect_cpu_support();
}

static inline void uuidv7_encode(uuidv7_bytes uuid, void *string) {
  uuidv7_avx2_encode(&uuid, string);
}

static inline uuidv7_decode_result uuidv7_decode(const void *_Nullable string, size_t length) {
  uuidv7_decode_result result = {{{0, 0}}, false};
  result.is_valid = uuidv7_avx2_decode(string, length, &result.bytes);
  return result;
}

#endif

#pragma clang assume_nonnull end

#endif
#endif
