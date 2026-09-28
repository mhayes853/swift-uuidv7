#ifndef CUUIDV7_H
#define CUUIDV7_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

// NB: These functions are only declared on platforms that have a SIMD implementation. All other
// platforms use the portable Swift implementation.
//
// 64-bit ARM implements them with NEON intrinsics, and x86-64 implements them with AVX2 intrinsics.
// Both are in this header so that Swift can inline them. (On x86-64, this requires a target CPU
// that always supports AVX2, see below.)
#if (defined(__aarch64__) || defined(__x86_64__)) && defined(__LP64__) && !defined(_WIN32)

#include <string.h>
#if defined(__aarch64__)
  #include <arm_neon.h>
#else
  #include <immintrin.h>
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

// MARK: - Shared Constants

/// The uppercase hex digit of each nibble.
static const uint8_t uuidv7_hex_digits[16] = {
  '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'
};

// NB: A character is a hex digit when the classes of its high and low nibbles intersect. The class
// of a digit's high nibble is also the offset of its value from its character.

/// Digit classes by high nibble, which are the offsets of digit values from their characters
/// (-'0', -('A' - 10), and -('a' - 10)). All of them have bit 7 set, and only the class of 0-9
/// (0x3_) has bit 4 set.
static const uint8_t uuidv7_high_nibble_classes[16] = {0, 0, 0, 0xD0, 0xC9, 0, 0xA9};

/// Digit classes by low nibble, where bit 4 is 0-9, and bit 7 is 1-6 (A-F and a-f).
static const uint8_t uuidv7_low_nibble_classes[16] = {
  0x10, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x10, 0x10, 0x10
};

// NB: The decoders describe which of the hyphen positions hold hyphens with a hyphen mask, where
// bit k is set when the kth hyphen position (8, 13, 18, or 23) holds a hyphen.

/// The expected string length for each hyphen mask (32 + the number of hyphens).
static const uint8_t uuidv7_decode_lengths[16] = {
  32, 33, 33, 34, 33, 34, 34, 35, 33, 34, 34, 35, 34, 35, 35, 36
};

#if defined(__aarch64__)

// MARK: - 64-bit ARM

static inline bool uuidv7_is_supported(void) {
  return true;
}

static inline void uuidv7_encode(uuidv7_bytes uuid, void *string) {
  // Shuffles of the hex digits, where index k is the high nibble digit of byte k, and index 16 + k
  // is its low nibble digit. Out of range indices leave hyphens in place.
  const uint8x16_t shuffle_0_16 = {
    0, 16, 1, 17, 2, 18, 3, 19, 0xFF, 4, 20, 5, 21, 0xFF, 6, 22
  };
  const uint8x16_t shuffle_16_32 = {
    7, 23, 0xFF, 8, 24, 9, 25, 0xFF, 10, 26, 11, 27, 12, 28, 13, 29
  };
  const uint8x16_t shuffle_32_36 = {14, 30, 15, 31};

  const uint8x16_t hex_digits = vld1q_u8(uuidv7_hex_digits);
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
    if (uuidv7_decode_lengths[mask] != length) return invalid;

    // Gather the digits of the layout. Hyphens anywhere else then fail the digit check.
    high = vqtbl3q_u8(string_0_32_and_last_16, vld1q_u8(gather_indices[mask]));
    low = vqtbl3q_u8(string_0_32_and_last_16, vld1q_u8(gather_indices[mask] + 16));
    valid = vdupq_n_u8(0xFF);
  }

  // Look up the classes of each digit's nibbles. (See uuidv7_high_nibble_classes.)
  const uint8x16_t high_nibble_classes = vld1q_u8(uuidv7_high_nibble_classes);
  const uint8x16_t low_nibble_classes = vld1q_u8(uuidv7_low_nibble_classes);
  const uint8x16_t low_nibble = vdupq_n_u8(0x0F);
  uint8x16_t high_offsets = vqtbl1q_u8(high_nibble_classes, vshrq_n_u8(high, 4));
  uint8x16_t low_offsets = vqtbl1q_u8(high_nibble_classes, vshrq_n_u8(low, 4));
  uint8x16_t high_classes = vqtbl1q_u8(low_nibble_classes, vandq_u8(high, low_nibble));
  uint8x16_t low_classes = vqtbl1q_u8(low_nibble_classes, vandq_u8(low, low_nibble));
  valid = vandq_u8(valid, vtstq_u8(high_offsets, high_classes));
  valid = vandq_u8(valid, vtstq_u8(low_offsets, low_classes));

  // Every lane must be valid. (shrn packs the 16 lane masks into 64 bits.)
  uint8x8_t valid_bits = vshrn_n_u16(vreinterpretq_u16_u8(valid), 4);
  if (vget_lane_u64(vreinterpret_u64_u8(valid_bits), 0) != UINT64_MAX) return invalid;

  uint8x16_t high_values = vaddq_u8(high, high_offsets);
  uint8x16_t low_values = vaddq_u8(low, low_offsets);
  uint64x2_t words = vreinterpretq_u64_u8(vsliq_n_u8(low_values, high_values, 4));
  uuidv7_decode_result result = {{{vgetq_lane_u64(words, 0), vgetq_lane_u64(words, 1)}}, true};
  return result;
}

#else

// MARK: - x86-64

// NB: Not every x86-64 CPU supports AVX2, so support is detected on first use and cached in
// uuidv7_cpu_support (0 until detected, then 1 when supported, and -1 otherwise). Concurrent first
// uses may both detect support, but they always store the same value. When the target CPU always
// supports AVX2, no detection is needed.
__attribute__((visibility("hidden"))) extern signed char uuidv7_cpu_support;
__attribute__((visibility("hidden"))) bool uuidv7_detect_cpu_support(void);

static inline bool uuidv7_is_supported(void) {
#if defined(__AVX2__)
  return true;
#else
  signed char support = __atomic_load_n(&uuidv7_cpu_support, __ATOMIC_RELAXED);
  return support != 0 ? support > 0 : uuidv7_detect_cpu_support();
#endif
}

// NB: The functions below are compiled for AVX2 regardless of the target CPU. Code can only be
// inlined into functions that are compiled for the same CPU features, so Swift calls them instead
// of inlining them, unless its target CPU always supports AVX2.
//
// AVX2 shuffles only move bytes within each 16 byte half of a 32 byte register, so 16 byte tables
// are broadcast to both halves, and shuffles of 32 bytes shuffle each half separately.

/// 0xFF at the hyphen positions of string[0..<32], and 0 elsewhere.
static const uint8_t uuidv7_avx2_hyphen_positions[32] = {
  0, 0, 0, 0, 0, 0, 0, 0, 0xFF, 0, 0, 0, 0, 0xFF, 0, 0,
  0, 0, 0xFF, 0, 0, 0, 0, 0xFF, 0, 0, 0, 0, 0, 0, 0, 0
};

static inline __attribute__((target("avx2"), always_inline)) __m256i uuidv7_avx2_load(
  const void *bytes
) {
  return _mm256_loadu_si256((const __m256i *)bytes);
}

static inline __attribute__((target("avx2"), always_inline)) __m256i uuidv7_avx2_broadcast(
  const void *bytes
) {
  return _mm256_broadcastsi128_si256(_mm_loadu_si128((const __m128i *)bytes));
}

static inline __attribute__((target("avx2"))) void uuidv7_avx2_encode(
  uuidv7_bytes uuid,
  void *string
) {
  // Shuffles of the hex digits of the high and low nibbles, where index k is the digit of byte k.
  // The first half is string[0..<16], and the second half is string[16..<32]. Out of range indices
  // leave zeros for the digits of the other nibble and the hyphens.
  static const uint8_t high_shuffle[32] = {
    0, 0xFF, 1, 0xFF, 2, 0xFF, 3, 0xFF, 0xFF, 4, 0xFF, 5, 0xFF, 0xFF, 6, 0xFF,
    7, 0xFF, 0xFF, 8, 0xFF, 9, 0xFF, 0xFF, 10, 0xFF, 11, 0xFF, 12, 0xFF, 13, 0xFF
  };
  static const uint8_t low_shuffle[32] = {
    0xFF, 0, 0xFF, 1, 0xFF, 2, 0xFF, 3, 0xFF, 0xFF, 4, 0xFF, 5, 0xFF, 0xFF, 6,
    0xFF, 7, 0xFF, 0xFF, 8, 0xFF, 9, 0xFF, 0xFF, 10, 0xFF, 11, 0xFF, 12, 0xFF, 13
  };

  const __m256i hex_digits = uuidv7_avx2_broadcast(uuidv7_hex_digits);
  const __m256i hyphens = _mm256_and_si256(
    uuidv7_avx2_load(uuidv7_avx2_hyphen_positions),
    _mm256_set1_epi8('-')
  );
  const __m256i low_nibble = _mm256_set1_epi8(0x0F);

  // Both halves hold the bytes of the UUID.
  __m128i words = _mm_set_epi64x((long long)uuid.words[1], (long long)uuid.words[0]);
  __m256i bytes = _mm256_broadcastsi128_si256(words);
  __m256i high_nibbles = _mm256_and_si256(_mm256_srli_epi16(bytes, 4), low_nibble);
  __m256i high = _mm256_shuffle_epi8(hex_digits, high_nibbles);
  __m256i low = _mm256_shuffle_epi8(hex_digits, _mm256_and_si256(bytes, low_nibble));

  // string[32..<36] is the end of the interleaved digits of bytes 8..<16, so this stores all of
  // them to string[20..<36], and the store of string[0..<32] below overwrites the rest.
  uint8_t *characters = string;
  __m128i high_0_16 = _mm256_castsi256_si128(high);
  __m128i low_0_16 = _mm256_castsi256_si128(low);
  _mm_storeu_si128((__m128i *)(characters + 20), _mm_unpackhi_epi8(high_0_16, low_0_16));

  high = _mm256_shuffle_epi8(high, uuidv7_avx2_load(high_shuffle));
  low = _mm256_shuffle_epi8(low, uuidv7_avx2_load(low_shuffle));
  __m256i string_0_32 = _mm256_or_si256(_mm256_or_si256(high, low), hyphens);
  _mm256_storeu_si256((__m256i *)characters, string_0_32);
}

/// Converts gather indices of string[0..<32] into shuffle indices of each half, where the indices
/// of characters in the other half are out of range.
static inline __attribute__((target("avx2"), always_inline)) __m256i uuidv7_avx2_half_indices(
  const uint8_t *indices
) {
  const __m256i half_starts = _mm256_set_m128i(_mm_set1_epi8(16), _mm_setzero_si128());
  __m256i offsets = _mm256_sub_epi8(uuidv7_avx2_broadcast(indices), half_starts);
  // Offsets of 0-15 stay in range, and the saturating add moves all others to 0x80 or more.
  return _mm256_adds_epu8(offsets, _mm256_set1_epi8(0x70));
}

/// Decodes 32 characters that must all be hex digits, where `invalid` is nonzero in lanes that are
/// otherwise invalid, and `gather_indices` are the indices of the high nibble digits followed by
/// the low nibble digits.
static inline __attribute__((target("avx2"), always_inline)) uuidv7_decode_result
uuidv7_avx2_decode_digits(__m256i digits, __m256i invalid, const uint8_t *gather_indices) {
  // Look up the classes of each digit's nibbles. (See uuidv7_high_nibble_classes. Non-ASCII
  // characters have no low nibble class.)
  const __m256i high_nibble_classes = uuidv7_avx2_broadcast(uuidv7_high_nibble_classes);
  const __m256i low_nibble_classes = uuidv7_avx2_broadcast(uuidv7_low_nibble_classes);
  __m256i high_nibbles = _mm256_and_si256(_mm256_srli_epi16(digits, 4), _mm256_set1_epi8(0x0F));
  __m256i offsets = _mm256_shuffle_epi8(high_nibble_classes, high_nibbles);
  __m256i classes = _mm256_and_si256(offsets, _mm256_shuffle_epi8(low_nibble_classes, digits));

  // Every lane must be valid.
  invalid = _mm256_or_si256(invalid, _mm256_cmpeq_epi8(classes, _mm256_setzero_si256()));
  if (__builtin_expect(_mm256_movemask_epi8(invalid) != 0, 0)) {
    const uuidv7_decode_result result = {{{0, 0}}, false};
    return result;
  }

  // Each half places the values of its digits at the indices of their bytes, and the digits of
  // each byte come from exactly one of the halves.
  __m256i values = _mm256_add_epi8(digits, offsets);
  __m256i high = _mm256_shuffle_epi8(values, uuidv7_avx2_half_indices(gather_indices));
  __m256i low = _mm256_shuffle_epi8(values, uuidv7_avx2_half_indices(gather_indices + 16));
  __m256i halves = _mm256_or_si256(_mm256_slli_epi16(high, 4), low);
  __m128i bytes = _mm_or_si128(_mm256_castsi256_si128(halves), _mm256_extracti128_si256(halves, 1));
  uuidv7_decode_result result = {{{0, 0}}, true};
  _mm_storeu_si128((__m128i *)result.bytes.words, bytes);
  return result;
}

static inline __attribute__((target("avx2"))) uuidv7_decode_result uuidv7_avx2_decode(
  const void *_Nullable string,
  size_t length
) {
  // For each hyphen mask, the index in the last 4 characters of the character that moves into each
  // hyphen position that holds a hyphen. (Entries for the other hyphen positions are unused.)
  static const uint8_t tail_indices[16][4] = {
    {0, 0, 0, 0},  // 0b0000
    {3, 0, 0, 0},  // 0b0001
    {0, 3, 0, 0},  // 0b0010
    {2, 3, 0, 0},  // 0b0011
    {0, 0, 3, 0},  // 0b0100
    {2, 0, 3, 0},  // 0b0101
    {0, 2, 3, 0},  // 0b0110
    {1, 2, 3, 0},  // 0b0111
    {0, 0, 0, 3},  // 0b1000
    {2, 0, 0, 3},  // 0b1001
    {0, 2, 0, 3},  // 0b1010
    {1, 2, 0, 3},  // 0b1011
    {0, 0, 2, 3},  // 0b1100
    {1, 0, 2, 3},  // 0b1101
    {0, 1, 2, 3},  // 0b1110
    {0, 1, 2, 3}   // 0b1111
  };
  // For each hyphen mask, the gather indices of the high nibble digits followed by the low nibble
  // digits, after moving string[32..<length] into the hyphen positions.
  static const uint8_t gather_indices[16][32] = {
    { 0,  2,  4,  6,  8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30,   // 0b0000
      1,  3,  5,  7,  9, 11, 13, 15, 17, 19, 21, 23, 25, 27, 29, 31},
    { 0,  2,  4,  6,  9, 11, 13, 15, 17, 19, 21, 23, 25, 27, 29, 31,   // 0b0001
      1,  3,  5,  7, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30,  8},
    { 0,  2,  4,  6,  8, 10, 12, 15, 17, 19, 21, 23, 25, 27, 29, 31,   // 0b0010
      1,  3,  5,  7,  9, 11, 14, 16, 18, 20, 22, 24, 26, 28, 30, 13},
    { 0,  2,  4,  6,  9, 11, 14, 16, 18, 20, 22, 24, 26, 28, 30,  8,   // 0b0011
      1,  3,  5,  7, 10, 12, 15, 17, 19, 21, 23, 25, 27, 29, 31, 13},
    { 0,  2,  4,  6,  8, 10, 12, 14, 16, 19, 21, 23, 25, 27, 29, 31,   // 0b0100
      1,  3,  5,  7,  9, 11, 13, 15, 17, 20, 22, 24, 26, 28, 30, 18},
    { 0,  2,  4,  6,  9, 11, 13, 15, 17, 20, 22, 24, 26, 28, 30,  8,   // 0b0101
      1,  3,  5,  7, 10, 12, 14, 16, 19, 21, 23, 25, 27, 29, 31, 18},
    { 0,  2,  4,  6,  8, 10, 12, 15, 17, 20, 22, 24, 26, 28, 30, 13,   // 0b0110
      1,  3,  5,  7,  9, 11, 14, 16, 19, 21, 23, 25, 27, 29, 31, 18},
    { 0,  2,  4,  6,  9, 11, 14, 16, 19, 21, 23, 25, 27, 29, 31, 13,   // 0b0111
      1,  3,  5,  7, 10, 12, 15, 17, 20, 22, 24, 26, 28, 30,  8, 18},
    { 0,  2,  4,  6,  8, 10, 12, 14, 16, 18, 20, 22, 25, 27, 29, 31,   // 0b1000
      1,  3,  5,  7,  9, 11, 13, 15, 17, 19, 21, 24, 26, 28, 30, 23},
    { 0,  2,  4,  6,  9, 11, 13, 15, 17, 19, 21, 24, 26, 28, 30,  8,   // 0b1001
      1,  3,  5,  7, 10, 12, 14, 16, 18, 20, 22, 25, 27, 29, 31, 23},
    { 0,  2,  4,  6,  8, 10, 12, 15, 17, 19, 21, 24, 26, 28, 30, 13,   // 0b1010
      1,  3,  5,  7,  9, 11, 14, 16, 18, 20, 22, 25, 27, 29, 31, 23},
    { 0,  2,  4,  6,  9, 11, 14, 16, 18, 20, 22, 25, 27, 29, 31, 13,   // 0b1011
      1,  3,  5,  7, 10, 12, 15, 17, 19, 21, 24, 26, 28, 30,  8, 23},
    { 0,  2,  4,  6,  8, 10, 12, 14, 16, 19, 21, 24, 26, 28, 30, 18,   // 0b1100
      1,  3,  5,  7,  9, 11, 13, 15, 17, 20, 22, 25, 27, 29, 31, 23},
    { 0,  2,  4,  6,  9, 11, 13, 15, 17, 20, 22, 25, 27, 29, 31, 18,   // 0b1101
      1,  3,  5,  7, 10, 12, 14, 16, 19, 21, 24, 26, 28, 30,  8, 23},
    { 0,  2,  4,  6,  8, 10, 12, 15, 17, 20, 22, 25, 27, 29, 31, 18,   // 0b1110
      1,  3,  5,  7,  9, 11, 14, 16, 19, 21, 24, 26, 28, 30, 13, 23},
    { 0,  2,  4,  6,  9, 11, 14, 16, 19, 21, 24, 26, 28, 30,  8, 18,   // 0b1111
      1,  3,  5,  7, 10, 12, 15, 17, 20, 22, 25, 27, 29, 31, 13, 23}
  };

  const uuidv7_decode_result invalid = {{{0, 0}}, false};
  const uint8_t *characters = string;
  const __m256i hyphen_positions = uuidv7_avx2_load(uuidv7_avx2_hyphen_positions);
  const __m256i hyphens = _mm256_and_si256(hyphen_positions, _mm256_set1_epi8('-'));

  // Every layout loads string[0..<32], which contains all of the hyphen positions, and then moves
  // string[32..<length] into the hyphen positions that hold hyphens. The hyphen positions are 0, 1,
  // 2, and 3 mod 4, so broadcasting the last 4 characters to every 4 bytes lines up character k
  // with hyphen position k.
  if (__builtin_expect(length == 36, 1)) {
    // The canonical layout moves string[32..<36] into every hyphen position. (It's the most common
    // layout, so it's the fall through path.)
    uint32_t tail;
    memcpy(&tail, characters + 32, 4);
    __m256i digits = uuidv7_avx2_load(characters);
    __m256i invalid_hyphens = _mm256_andnot_si256(
      _mm256_cmpeq_epi8(digits, hyphens),
      hyphen_positions
    );
    digits = _mm256_blendv_epi8(digits, _mm256_set1_epi32((int)tail), hyphen_positions);
    return uuidv7_avx2_decode_digits(digits, invalid_hyphens, gather_indices[15]);
  }
  if (length == 32) {
    // The digits are already in place, and any hyphens fail the digit check.
    __m256i digits = uuidv7_avx2_load(characters);
    return uuidv7_avx2_decode_digits(digits, _mm256_setzero_si256(), gather_indices[0]);
  }
  if (length - 33 > 2) return invalid;  // length < 33 || length > 35

  uint32_t tail;
  memcpy(&tail, characters + length - 4, 4);
  __m256i digits = uuidv7_avx2_load(characters);
  __m256i is_hyphen = _mm256_and_si256(_mm256_cmpeq_epi8(digits, hyphens), hyphen_positions);
  // Moves bits 8, 13, 18, and 23 of the byte mask to bits 20-23.
  uint32_t mask = ((uint32_t)_mm256_movemask_epi8(is_hyphen) * 0x1111) >> 20 & 0xF;

  // The hyphens must account for every byte beyond the 32 hex digits.
  if (uuidv7_decode_lengths[mask] != length) return invalid;

  // Move string[32..<length] into the hyphen positions. Hyphens anywhere else then fail the digit
  // check.
  uint32_t indices;
  memcpy(&indices, tail_indices[mask], 4);
  __m256i tails = _mm256_set1_epi32((int)tail);
  __m256i moved = _mm256_shuffle_epi8(tails, _mm256_set1_epi32((int)indices));
  digits = _mm256_blendv_epi8(digits, moved, is_hyphen);
  return uuidv7_avx2_decode_digits(digits, _mm256_setzero_si256(), gather_indices[mask]);
}

static inline void uuidv7_encode(uuidv7_bytes uuid, void *string) {
  uuidv7_avx2_encode(uuid, string);
}

static inline uuidv7_decode_result uuidv7_decode(const void *_Nullable string, size_t length) {
  return uuidv7_avx2_decode(string, length);
}

#endif

#pragma clang assume_nonnull end

#endif
#endif
