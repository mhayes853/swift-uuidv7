#ifndef CUUIDV7_H
#define CUUIDV7_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#if (defined(__aarch64__) || defined(__x86_64__)) && defined(__LP64__) && !defined(_WIN32)

#include <string.h>
#if defined(__aarch64__)
  #include <arm_neon.h>
#else
  #include <immintrin.h>
#endif

#pragma clang assume_nonnull begin

typedef struct {
  uint64_t words[2];
} uuidv7_bytes;

typedef struct {
  uuidv7_bytes bytes;
  bool is_valid;
} uuidv7_decode_result;

static inline bool uuidv7_is_simd_supported(void);

static inline void uuidv7_encode(uuidv7_bytes uuid, void *string, bool lowercased);

static inline uuidv7_decode_result uuidv7_decode(const void *string);

static const uint8_t uuidv7_uppercase_hex_digits[16] = {
  '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'
};

static const uint8_t uuidv7_lowercase_hex_digits[16] = {
  '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f'
};

static const uint8_t uuidv7_high_nibble_classes[16] = {0, 0, 0, 0xD0, 0xC9, 0, 0xA9};

static const uint8_t uuidv7_low_nibble_classes[16] = {
  0x10, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x10, 0x10, 0x10
};

#if defined(__aarch64__)

static inline bool uuidv7_is_simd_supported(void) {
  return true;
}

static inline void uuidv7_encode(uuidv7_bytes uuid, void *string, bool lowercased) {
  const uint8x16_t shuffle_0_16 = {
    0, 16, 1, 17, 2, 18, 3, 19, 0xFF, 4, 20, 5, 21, 0xFF, 6, 22
  };
  const uint8x16_t shuffle_16_32 = {
    7, 23, 0xFF, 8, 24, 9, 25, 0xFF, 10, 26, 11, 27, 12, 28, 13, 29
  };
  const uint8x16_t shuffle_32_36 = {14, 30, 15, 31};

  const uint8x16_t hex_digits = vld1q_u8(
    lowercased ? uuidv7_lowercase_hex_digits : uuidv7_uppercase_hex_digits
  );
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

static const uint8_t uuidv7_neon_hex_values[64] = {
  0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0, 0, 0, 0, 0, 0,
  0, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F, 0, 0, 0, 0, 0, 0, 0, 0, 0
};

static inline uuidv7_decode_result uuidv7_decode(const void *string) {
  static const uint8_t shuffles[64] = {
    0, 2, 4, 6, 9, 11, 14, 16, 19, 21, 24, 26, 28, 30, 32, 34,
    1, 3, 5, 7, 10, 12, 15, 17, 20, 22, 25, 27, 29, 31, 33, 35,
    8, 13, 18, 23, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
    '-', '-', '-', '-', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  };

  const uint8x16x4_t shuffle = vld1q_u8_x4(shuffles);
  const uint8x16x4_t hex_values = vld1q_u8_x4(uuidv7_neon_hex_values);
  const uint8x16_t zero = vdupq_n_u8('0');

  const uint8_t *characters = string;
  uint32_t tail;
  memcpy(&tail, characters + 32, 4);
  uint8x16x3_t string_0_36 = {{
    vld1q_u8(characters),
    vld1q_u8(characters + 16),
    vreinterpretq_u8_u32(vsetq_lane_u32(tail, vdupq_n_u32(0), 0))
  }};
  uint8x16_t high = vqtbl3q_u8(string_0_36, shuffle.val[0]);
  uint8x16_t low = vqtbl3q_u8(string_0_36, shuffle.val[1]);
  high = vqtbl4q_u8(hex_values, vsubq_u8(high, zero));
  low = vqtbl4q_u8(hex_values, vsubq_u8(low, zero));

  uint8x16x2_t string_0_32 = {{string_0_36.val[0], string_0_36.val[1]}};
  uint8x16_t valid = vceqq_u8(vqtbl2q_u8(string_0_32, shuffle.val[2]), shuffle.val[3]);
  valid = vandq_u8(valid, vandq_u8(high, low));
  if (vminvq_u8(valid) == 0) {
    const uuidv7_decode_result result = {{{0, 0}}, false};
    return result;
  }

  uint64x2_t words = vreinterpretq_u64_u8(vsliq_n_u8(low, high, 4));
  uuidv7_decode_result result = {{{vgetq_lane_u64(words, 0), vgetq_lane_u64(words, 1)}}, true};
  return result;
}

#else

static inline bool uuidv7_is_simd_supported(void) {
#if defined(__AVX2__)
  return true;
#else
  return __builtin_cpu_supports("avx2");
#endif
}

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

static inline __attribute__((target("avx2"))) void uuidv7_encode(
  uuidv7_bytes uuid,
  void *string,
  bool lowercased
) {
  static const uint8_t shuffle[32] = {
    0, 1, 2, 3, 4, 5, 6, 7, 0xFF, 8, 9, 10, 11, 0xFF, 12, 13,
    0, 1, 0xFF, 2, 3, 4, 5, 0xFF, 6, 7, 8, 9, 10, 11, 12, 13
  };

  const __m256i hex_digits = uuidv7_avx2_broadcast(
    lowercased ? uuidv7_lowercase_hex_digits : uuidv7_uppercase_hex_digits
  );
  const __m256i hyphens = _mm256_and_si256(
    uuidv7_avx2_load(uuidv7_avx2_hyphen_positions),
    _mm256_set1_epi8('-')
  );

  __m128i bytes = _mm_set_epi64x((long long)uuid.words[1], (long long)uuid.words[0]);
  __m256i words = _mm256_cvtepu8_epi16(bytes);
  __m256i nibbles = _mm256_srli_epi16(
    _mm256_or_si256(words, _mm256_slli_epi16(words, 12)), 4
  );
  __m256i hex = _mm256_shuffle_epi8(hex_digits, nibbles);
  __m128i digits_0_16 = _mm256_castsi256_si128(hex);
  __m128i digits_16_32 = _mm256_extracti128_si256(hex, 1);

  __m256i digits = _mm256_inserti128_si256(
    _mm256_castsi128_si256(digits_0_16),
    _mm_alignr_epi8(digits_16_32, digits_0_16, 14),
    1
  );
  uint8_t *characters = string;
  _mm_storeu_si128((__m128i *)(characters + 20), digits_16_32);
  _mm256_storeu_si256((__m256i *)characters, _mm256_or_si256(
    _mm256_shuffle_epi8(digits, uuidv7_avx2_load(shuffle)), hyphens
  ));
}

static inline __attribute__((target("avx2"))) uuidv7_decode_result uuidv7_decode(
  const void *string
) {
  static const uint8_t shuffle[32] = {
    0, 1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 14, 15, 8, 13,
    0, 1, 3, 4, 5, 6, 8, 9, 10, 11, 12, 13, 14, 15, 2, 7
  };
  static const uint8_t byte_shuffle[16] = {
    0, 1, 2, 3, 4, 5, 6, 8, 9, 10, 11, 12, 13, 14, 7, 15
  };

  const __m256i hyphen_positions = uuidv7_avx2_load(uuidv7_avx2_hyphen_positions);
  const __m256i hyphens = _mm256_and_si256(hyphen_positions, _mm256_set1_epi8('-'));
  const __m256i high_nibble_classes = uuidv7_avx2_broadcast(uuidv7_high_nibble_classes);
  const __m256i low_nibble_classes = uuidv7_avx2_broadcast(uuidv7_low_nibble_classes);

  const uint8_t *characters = string;
  uint32_t tail;
  memcpy(&tail, characters + 32, 4);
  __m256i digits = uuidv7_avx2_load(characters);
  __m256i invalid = _mm256_andnot_si256(_mm256_cmpeq_epi8(digits, hyphens), hyphen_positions);
  digits = _mm256_blendv_epi8(digits, _mm256_set1_epi32((int)tail), hyphen_positions);

  __m256i high_nibbles = _mm256_and_si256(_mm256_srli_epi16(digits, 4), _mm256_set1_epi8(0x0F));
  __m256i offsets = _mm256_shuffle_epi8(high_nibble_classes, high_nibbles);
  __m256i classes = _mm256_and_si256(offsets, _mm256_shuffle_epi8(low_nibble_classes, digits));

  invalid = _mm256_or_si256(invalid, _mm256_cmpeq_epi8(classes, _mm256_setzero_si256()));
  if (__builtin_expect(_mm256_movemask_epi8(invalid) != 0, 0)) {
    const uuidv7_decode_result result = {{{0, 0}}, false};
    return result;
  }

  __m256i values = _mm256_add_epi8(digits, offsets);
  __m256i nibbles = _mm256_shuffle_epi8(values, uuidv7_avx2_load(shuffle));
  __m256i pairs = _mm256_maddubs_epi16(nibbles, _mm256_set1_epi16(0x0110));
  __m128i packed = _mm_packus_epi16(
    _mm256_castsi256_si128(pairs), _mm256_extracti128_si256(pairs, 1)
  );
  __m128i bytes = _mm_shuffle_epi8(packed, _mm_loadu_si128((const __m128i *)byte_shuffle));
  uuidv7_decode_result result = {{{0, 0}}, true};
  _mm_storeu_si128((__m128i *)result.bytes.words, bytes);
  return result;
}

#endif

#pragma clang assume_nonnull end

#endif
#endif
