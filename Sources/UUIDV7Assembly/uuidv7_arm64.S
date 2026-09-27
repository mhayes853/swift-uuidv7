// NEON implementations of UUIDV7 generation, string encoding, and string decoding for 64-bit ARM.
// See include/UUIDV7Assembly.h for the C interface.
//
// This file assembles to nothing on other architectures (and on 64-bit ARM Windows), which use
// the portable Swift implementation instead.

#if defined(__aarch64__) && defined(__LP64__) && !defined(_WIN32)

// MARK: - Platform Macros

#if defined(__APPLE__)
  #define SEPARATOR %%
  #define SYMBOL(name) _##name
  #define LOCAL(name) L##name
  #define ADDRESS(reg, label) adrp reg, label@PAGE SEPARATOR add reg, reg, label@PAGEOFF
  #define CONST_SECTION .section __TEXT,__const
  #define FUNCTION_TYPE(name)
  #define FUNCTION_SIZE(name)
  #define FUNCTION_LANDING_PAD
#else
  #define SEPARATOR ;
  #define SYMBOL(name) name
  #define LOCAL(name) .L##name
  #define ADDRESS(reg, label) adrp reg, label SEPARATOR add reg, reg, :lo12:label
  #define CONST_SECTION .section .rodata
  #define FUNCTION_TYPE(name) .type name, %function
  #define FUNCTION_SIZE(name) .size name, .-name
  #if defined(__ARM_FEATURE_BTI_DEFAULT)
    #define FUNCTION_LANDING_PAD hint #34 // bti c
  #else
    #define FUNCTION_LANDING_PAD
  #endif
#endif

#define BEGIN_FUNCTION(name) \
  .globl SYMBOL(name) SEPARATOR \
  FUNCTION_TYPE(SYMBOL(name)) SEPARATOR \
  .p2align 4 SEPARATOR \
  SYMBOL(name): SEPARATOR \
  FUNCTION_LANDING_PAD

#define END_FUNCTION(name) FUNCTION_SIZE(SYMBOL(name))

  .text

// MARK: - Generation

// void uuidv7_apply_timestamp(void *uuid, uint64_t unix_millis)
//
// x0: 16 random bytes that are turned into the UUID in place.
// x1: The unix timestamp in milliseconds.
BEGIN_FUNCTION(uuidv7_apply_timestamp)
  lsl x9, x1, #16
  orr x9, x9, #0x7000                     // unix_ts_ms (48 bits) | ver (4 bits) | 0 (12 bits)
  rev x9, x9                              // Big-endian byte order.
  fmov d1, x9
  ADDRESS(x10, LOCAL(generation_constants))
  ldp q2, q3, [x10]                       // v2 = variant, v3 = random bits of rand_a and rand_b
  orr v1.16b, v1.16b, v2.16b
  ldr q0, [x0]
  bit v1.16b, v0.16b, v3.16b              // Keep the random bits of rand_a and rand_b.
  str q1, [x0]
  ret
END_FUNCTION(uuidv7_apply_timestamp)

// void uuidv7_apply_monotonic_timestamp(
//   uuidv7_monotonic_state *state,
//   void *uuid,
//   uint64_t unix_millis
// )
//
// x0: The monotonic state (previous_timestamp at 0, offset at 8, sequence at 16).
// x1: 16 random bytes that are turned into the UUID in place.
// x2: The unix timestamp in milliseconds.
BEGIN_FUNCTION(uuidv7_apply_monotonic_timestamp)
  ldp x9, x10, [x0]                       // x9 = previous_timestamp, x10 = offset
  ldrh w11, [x0, #16]                     // w11 = sequence
  add x12, x2, x10                        // x12 = timestamp = unix_millis &+ offset
  add w13, w11, #1
  and w13, w13, #0xFFFF                   // w13 = sequence &+ 1
  sub x14, x9, x12                        // x14 = previous_timestamp - timestamp

  // timestamp == previous_timestamp: sequence &+= 1
  // timestamp < previous_timestamp: sequence &+= 1, offset = x14, timestamp = previous_timestamp
  // timestamp > previous_timestamp: sequence = 0, offset = 0
  cmp x12, x9
  csel w11, w13, wzr, ls
  csel x10, x14, x10, lo
  csel x10, xzr, x10, hi
  csel x12, x9, x12, lo

  // When the 12-bit counter overflows, borrow the next millisecond.
  cmp w11, #0xFFF
  csel w11, wzr, w11, hi
  cinc x12, x12, hi

  stp x12, x10, [x0]
  strh w11, [x0, #16]

  orr x9, x11, x12, lsl #16               // unix_ts_ms (48 bits) | 0 (4 bits) | sequence (12 bits)
  orr x9, x9, #0x7000                     // ver
  rev x9, x9                              // Big-endian byte order.
  fmov d1, x9
  ADDRESS(x10, LOCAL(generation_constants))
  ldr q2, [x10]                           // v2 = variant
  ldr q3, [x10, #32]                      // v3 = random bits of rand_b
  orr v1.16b, v1.16b, v2.16b
  ldr q0, [x1]
  bit v1.16b, v0.16b, v3.16b              // Keep the random bits of rand_b.
  str q1, [x1]
  ret
END_FUNCTION(uuidv7_apply_monotonic_timestamp)

// MARK: - Encoding

// void uuidv7_encode(const void *uuid, void *string)
//
// x0: The 16 UUID bytes.
// x1: The 36 byte buffer for the uppercase hyphenated string.
BEGIN_FUNCTION(uuidv7_encode)
  ldr q0, [x0]
  ADDRESS(x9, LOCAL(encode_constants))
  ldp q1, q2, [x9]                        // v1 = hex digits, v2 = shuffle of string[0..<16]
  ldr q3, [x9, #32]                       // v3 = shuffle of string[16..<32]

  movi v4.16b, #0x0F
  ushr v5.16b, v0.16b, #4                 // High nibbles.
  and v6.16b, v0.16b, v4.16b              // Low nibbles.
  zip1 v16.16b, v5.16b, v6.16b            // Nibbles of bytes 0-7 in string order.
  zip2 v17.16b, v5.16b, v6.16b            // Nibbles of bytes 8-15 in string order.
  tbl v16.16b, {v1.16b}, v16.16b          // v16 = hex[0..<16]
  tbl v17.16b, {v1.16b}, v17.16b          // v17 = hex[16..<32]

  // Out of range shuffle indices leave the hyphens in place.
  movi v18.16b, #0x2D                     // -
  movi v19.16b, #0x2D
  tbx v18.16b, {v16.16b, v17.16b}, v2.16b
  tbx v19.16b, {v16.16b, v17.16b}, v3.16b

  stp q18, q19, [x1]                      // string[0..<32]
  add x9, x1, #32
  st1 {v17.s}[3], [x9]                    // string[32..<36] = hex[28..<32]
  ret
END_FUNCTION(uuidv7_encode)

// MARK: - Decoding

// bool uuidv7_decode(const void *string, size_t length, void *uuid)
//
// x0: The UTF-8 string.
// x1: The length of the string in bytes.
// x2: The 16 byte buffer for the UUID, which is only written to on success.
//
// This accepts exactly what the portable Swift implementation accepts: 32 case-insensitive hex
// digits, with hyphens allowed at any subset of the string positions 8, 13, 18, and 23. Therefore,
// valid strings are 32-36 bytes long, and have exactly (length - 32) hyphens.
BEGIN_FUNCTION(uuidv7_decode)
  sub x9, x1, #32
  cmp x9, #4
  b.hi LOCAL(decode_failure)              // length < 32 || length > 36

  ldp q0, q1, [x0]                        // v0, v1 = string[0..<32]
  add x9, x0, x1
  ldur q2, [x9, #-16]                     // v2 = string[(length - 16)..<length]
  ADDRESS(x10, LOCAL(decode_constants))

  // w11 = A 4-bit mask of the hyphen positions that hold hyphens.
  ldp q3, q4, [x10]                       // v3 = hyphen positions, v4 = hyphen mask bits
  tbl v3.16b, {v0.16b, v1.16b}, v3.16b
  movi v5.16b, #0x2D                      // -
  cmeq v3.16b, v3.16b, v5.16b
  and v3.16b, v3.16b, v4.16b
  addv b3, v3.16b
  umov w11, v3.b[0]

  // The hyphens must account for every byte beyond the 32 hex digits.
  add x12, x10, x11
  ldrb w12, [x12, #32]
  cmp x12, x1
  b.ne LOCAL(decode_failure)

  // Gather the hex digits of the high and low nibbles of each byte, skipping the hyphens.
  add x12, x10, x11, lsl #5
  ldp q16, q17, [x12, #48]
  tbl v16.16b, {v0.16b, v1.16b, v2.16b}, v16.16b
  tbl v17.16b, {v0.16b, v1.16b, v2.16b}, v17.16b

  // Convert the hex digits to their values.
  movi v18.16b, #0x30                     // 0
  movi v19.16b, #10
  movi v20.16b, #0x20                     // ASCII lowercase bit.
  movi v21.16b, #0x61                     // a
  movi v22.16b, #6
  sub v23.16b, v16.16b, v18.16b           // High nibble digit values.
  sub v24.16b, v17.16b, v18.16b           // Low nibble digit values.
  orr v25.16b, v16.16b, v20.16b
  orr v26.16b, v17.16b, v20.16b
  sub v25.16b, v25.16b, v21.16b           // High nibble letter offsets from a.
  sub v26.16b, v26.16b, v21.16b           // Low nibble letter offsets from a.
  cmhi v27.16b, v19.16b, v23.16b          // High nibble is a digit.
  cmhi v28.16b, v19.16b, v24.16b          // Low nibble is a digit.
  cmhi v29.16b, v22.16b, v25.16b          // High nibble is a letter.
  cmhi v30.16b, v22.16b, v26.16b          // Low nibble is a letter.
  add v25.16b, v25.16b, v19.16b           // High nibble letter values.
  add v26.16b, v26.16b, v19.16b           // Low nibble letter values.
  bit v23.16b, v25.16b, v29.16b           // High nibble values.
  bit v24.16b, v26.16b, v30.16b           // Low nibble values.

  // Every character must be a digit or a letter.
  orr v27.16b, v27.16b, v29.16b
  orr v28.16b, v28.16b, v30.16b
  and v27.16b, v27.16b, v28.16b
  uminv b27, v27.16b
  umov w9, v27.b[0]
  cbz w9, LOCAL(decode_failure)

  sli v24.16b, v23.16b, #4                // (high << 4) | low
  str q24, [x2]
  mov w0, #1
  ret
LOCAL(decode_failure):
  mov w0, #0
  ret
END_FUNCTION(uuidv7_decode)

// MARK: - Constants

  CONST_SECTION

  .p2align 4
LOCAL(generation_constants):
  // +0: The variant (0b10) in byte 8.
  .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
  // +16: The random bits of rand_a (bytes 6-7) and rand_b (bytes 8-15).
  .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0F, 0xFF, 0x3F, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF
  // +32: The random bits of rand_b (bytes 8-15).
  .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x3F, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF

  .p2align 4
LOCAL(encode_constants):
  // +0: The hex digits.
  .ascii "0123456789ABCDEF"
  // +16: string[0..<16] = hex[0..<8] - hex[8..<12] - hex[12..<14]
  .byte 0, 1, 2, 3, 4, 5, 6, 7, 0xFF, 8, 9, 10, 11, 0xFF, 12, 13
  // +32: string[16..<32] = hex[14..<16] - hex[16..<20] - hex[20..<28]
  .byte 14, 15, 0xFF, 16, 17, 18, 19, 0xFF, 20, 21, 22, 23, 24, 25, 26, 27

  .p2align 4
LOCAL(decode_constants):
  // +0: The string positions that may hold hyphens. (Out of range indices gather 0.)
  .byte 8, 13, 18, 23, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF
  // +16: The bit of each hyphen position in the hyphen mask.
  .byte 1, 2, 4, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  // +32: The expected string length for each hyphen mask (32 + the number of hyphens).
  .byte 32, 33, 33, 34, 33, 34, 34, 35, 33, 34, 34, 35, 34, 35, 35, 36
  // +48: For each hyphen mask, the tbl indices of the high nibble hex digits followed by the low
  // nibble hex digits. Indices 0-31 are string[0..<32], and indices 32-47 are
  // string[(length - 16)..<length].
  .byte  0,  2,  4,  6,  8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30  // 0b0000 high
  .byte  1,  3,  5,  7,  9, 11, 13, 15, 17, 19, 21, 23, 25, 27, 29, 31  // 0b0000 low
  .byte  0,  2,  4,  6,  9, 11, 13, 15, 17, 19, 21, 23, 25, 27, 29, 31  // 0b0001 high
  .byte  1,  3,  5,  7, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 47  // 0b0001 low
  .byte  0,  2,  4,  6,  8, 10, 12, 15, 17, 19, 21, 23, 25, 27, 29, 31  // 0b0010 high
  .byte  1,  3,  5,  7,  9, 11, 14, 16, 18, 20, 22, 24, 26, 28, 30, 47  // 0b0010 low
  .byte  0,  2,  4,  6,  9, 11, 14, 16, 18, 20, 22, 24, 26, 28, 30, 46  // 0b0011 high
  .byte  1,  3,  5,  7, 10, 12, 15, 17, 19, 21, 23, 25, 27, 29, 31, 47  // 0b0011 low
  .byte  0,  2,  4,  6,  8, 10, 12, 14, 16, 19, 21, 23, 25, 27, 29, 31  // 0b0100 high
  .byte  1,  3,  5,  7,  9, 11, 13, 15, 17, 20, 22, 24, 26, 28, 30, 47  // 0b0100 low
  .byte  0,  2,  4,  6,  9, 11, 13, 15, 17, 20, 22, 24, 26, 28, 30, 46  // 0b0101 high
  .byte  1,  3,  5,  7, 10, 12, 14, 16, 19, 21, 23, 25, 27, 29, 31, 47  // 0b0101 low
  .byte  0,  2,  4,  6,  8, 10, 12, 15, 17, 20, 22, 24, 26, 28, 30, 46  // 0b0110 high
  .byte  1,  3,  5,  7,  9, 11, 14, 16, 19, 21, 23, 25, 27, 29, 31, 47  // 0b0110 low
  .byte  0,  2,  4,  6,  9, 11, 14, 16, 19, 21, 23, 25, 27, 29, 31, 46  // 0b0111 high
  .byte  1,  3,  5,  7, 10, 12, 15, 17, 20, 22, 24, 26, 28, 30, 45, 47  // 0b0111 low
  .byte  0,  2,  4,  6,  8, 10, 12, 14, 16, 18, 20, 22, 25, 27, 29, 31  // 0b1000 high
  .byte  1,  3,  5,  7,  9, 11, 13, 15, 17, 19, 21, 24, 26, 28, 30, 47  // 0b1000 low
  .byte  0,  2,  4,  6,  9, 11, 13, 15, 17, 19, 21, 24, 26, 28, 30, 46  // 0b1001 high
  .byte  1,  3,  5,  7, 10, 12, 14, 16, 18, 20, 22, 25, 27, 29, 31, 47  // 0b1001 low
  .byte  0,  2,  4,  6,  8, 10, 12, 15, 17, 19, 21, 24, 26, 28, 30, 46  // 0b1010 high
  .byte  1,  3,  5,  7,  9, 11, 14, 16, 18, 20, 22, 25, 27, 29, 31, 47  // 0b1010 low
  .byte  0,  2,  4,  6,  9, 11, 14, 16, 18, 20, 22, 25, 27, 29, 31, 46  // 0b1011 high
  .byte  1,  3,  5,  7, 10, 12, 15, 17, 19, 21, 24, 26, 28, 30, 45, 47  // 0b1011 low
  .byte  0,  2,  4,  6,  8, 10, 12, 14, 16, 19, 21, 24, 26, 28, 30, 46  // 0b1100 high
  .byte  1,  3,  5,  7,  9, 11, 13, 15, 17, 20, 22, 25, 27, 29, 31, 47  // 0b1100 low
  .byte  0,  2,  4,  6,  9, 11, 13, 15, 17, 20, 22, 25, 27, 29, 31, 46  // 0b1101 high
  .byte  1,  3,  5,  7, 10, 12, 14, 16, 19, 21, 24, 26, 28, 30, 45, 47  // 0b1101 low
  .byte  0,  2,  4,  6,  8, 10, 12, 15, 17, 20, 22, 25, 27, 29, 31, 46  // 0b1110 high
  .byte  1,  3,  5,  7,  9, 11, 14, 16, 19, 21, 24, 26, 28, 30, 45, 47  // 0b1110 low
  .byte  0,  2,  4,  6,  9, 11, 14, 16, 19, 21, 24, 26, 28, 30, 44, 46  // 0b1111 high
  .byte  1,  3,  5,  7, 10, 12, 15, 17, 20, 22, 25, 27, 29, 31, 45, 47  // 0b1111 low

// MARK: - Object File Metadata

#if defined(__APPLE__)
  .subsections_via_symbols
#elif defined(__ARM_FEATURE_BTI_DEFAULT)
  // Marks the functions above as compatible with BTI (they have landing pads) and PAC (they're
  // leaf functions that never spill the link register, so they have nothing to sign).
  .pushsection .note.gnu.property, "a"
  .p2align 3
  .word 4                                 // Name size.
  .word 16                                // Descriptor size.
  .word 5                                 // NT_GNU_PROPERTY_TYPE_0
  .asciz "GNU"
  .word 0xC0000000                        // GNU_PROPERTY_AARCH64_FEATURE_1_AND
  .word 4                                 // Property size.
  .word 3                                 // GNU_PROPERTY_AARCH64_FEATURE_1_BTI | _PAC
  .word 0                                 // Padding.
  .popsection
#endif

#endif

// NB: Without this, linking this object into an ELF binary implies an executable stack, even on
// architectures where the rest of this file assembles to nothing.
#if defined(__ELF__)
  .section .note.GNU-stack, "", %progbits
#endif
