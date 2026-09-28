// NEON implementations of UUIDV7 string encoding and decoding for 64-bit ARM.
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

// MARK: - Encoding

// void uuidv7_encode(const void *uuid, void *string)
//
// x0: The 16 UUID bytes.
// x1: The 36 byte buffer for the uppercase hyphenated string.
BEGIN_FUNCTION(uuidv7_encode)
  ldr q0, [x0]
  ADDRESS(x9, LOCAL(encode_constants))
  ldp q16, q17, [x9]                      // v16 = hex digits, v17 = shuffle of string[0..<16]
  ldp q18, q19, [x9, #32]                 // v18, v19 = shuffles of string[16..<32], [32..<36]

  movi v3.16b, #0x0F
  ushr v1.16b, v0.16b, #4
  and v2.16b, v0.16b, v3.16b
  tbl v1.16b, {v16.16b}, v1.16b           // Hex digits of the high nibbles.
  tbl v2.16b, {v16.16b}, v2.16b           // Hex digits of the low nibbles.

  // Each shuffle interleaves the digits, and its out of range indices leave the hyphens in place.
  movi v4.16b, #0x2D                      // -
  movi v5.16b, #0x2D
  tbx v4.16b, {v1.16b, v2.16b}, v17.16b
  tbx v5.16b, {v1.16b, v2.16b}, v18.16b
  tbl v6.16b, {v1.16b, v2.16b}, v19.16b

  stp q4, q5, [x1]                        // string[0..<32]
  str s6, [x1, #32]                       // string[32..<36]
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
//
// The canonical 36 byte layout gathers its digits with fixed indices, which keeps data dependent
// loads off of its critical path. Other layouts first work out which hyphens are present.
BEGIN_FUNCTION(uuidv7_decode)
  ADDRESS(x9, LOCAL(decode_constants))
  ldp q5, q6, [x9, #32]                   // v5, v6 = digit classes by high nibble, by low nibble
  cmp x1, #36
  b.ne LOCAL(decode_irregular_layout)

  ldp q0, q1, [x0]                        // v0, v1 = string[0..<32]
  ldr s2, [x0, #32]                       // v2 = string[32..<36]
  ldp q3, q4, [x9]                        // v3, v4 = gather indices of the high and low nibbles
  ldr q7, [x9, #64]                       // v7 = hyphen positions
  tbl v16.16b, {v0.16b, v1.16b, v2.16b}, v3.16b
  tbl v17.16b, {v0.16b, v1.16b, v2.16b}, v4.16b

  // v18 = 0xFF in every lane when string[8, 13, 18, 23] are all hyphens.
  movi v18.16b, #0x2D                     // -
  mov v19.16b, v18.16b
  tbx v19.16b, {v0.16b, v1.16b}, v7.16b
  cmeq v18.16b, v19.16b, v18.16b

// v16 = high nibble digits, v17 = low nibble digits, v18 = 0xFF in lanes that are otherwise valid.
LOCAL(decode_digits):
  // A character is a hex digit when the classes of its high and low nibbles intersect. The high
  // nibble class of a letter also holds the offset of its value (9) in its upper nibble.
  movi v20.16b, #0x0F
  ushr v21.16b, v16.16b, #4
  ushr v22.16b, v17.16b, #4
  and v23.16b, v16.16b, v20.16b
  and v24.16b, v17.16b, v20.16b
  tbl v21.16b, {v5.16b}, v21.16b
  tbl v22.16b, {v5.16b}, v22.16b
  tbl v25.16b, {v6.16b}, v23.16b
  tbl v26.16b, {v6.16b}, v24.16b
  cmtst v25.16b, v21.16b, v25.16b         // High nibble digit is valid.
  cmtst v26.16b, v22.16b, v26.16b         // Low nibble digit is valid.
  usra v23.16b, v21.16b, #4               // High nibble values.
  usra v24.16b, v22.16b, #4               // Low nibble values.

  // Every lane must be valid. (shrn packs the 16 lane masks into 64 bits.)
  and v25.16b, v25.16b, v26.16b
  and v25.16b, v25.16b, v18.16b
  shrn v25.8b, v25.8h, #4
  fmov x10, d25
  cmn x10, #1
  b.ne LOCAL(decode_failure)

  sli v24.16b, v23.16b, #4                // (high << 4) | low
  str q24, [x2]
  mov w0, #1
  ret

LOCAL(decode_irregular_layout):
  sub x10, x1, #32
  cmp x10, #3
  b.hi LOCAL(decode_failure)              // length < 32 || length > 35
  ldp q0, q1, [x0]                        // v0, v1 = string[0..<32]
  add x10, x0, x1
  ldur q2, [x10, #-16]                    // v2 = string[(length - 16)..<length]

  // w11 = A 4-bit mask of the hyphen positions that hold hyphens.
  ldp q3, q4, [x9, #64]                   // v3 = hyphen positions, v4 = hyphen mask bits
  tbl v3.16b, {v0.16b, v1.16b}, v3.16b
  movi v7.16b, #0x2D                      // -
  cmeq v3.16b, v3.16b, v7.16b
  and v3.16b, v3.16b, v4.16b
  addv b3, v3.16b
  umov w11, v3.b[0]

  // The hyphens must account for every byte beyond the 32 hex digits.
  add x12, x9, x11
  ldrb w12, [x12, #96]
  cmp x12, x1
  b.ne LOCAL(decode_failure)

  // Gather the digits of the layout. Hyphens anywhere else then fail the digit check.
  add x12, x9, x11, lsl #5
  ldp q3, q4, [x12, #112]
  tbl v16.16b, {v0.16b, v1.16b, v2.16b}, v3.16b
  tbl v17.16b, {v0.16b, v1.16b, v2.16b}, v4.16b
  movi v18.16b, #0xFF
  b LOCAL(decode_digits)

LOCAL(decode_failure):
  mov w0, #0
  ret
END_FUNCTION(uuidv7_decode)

// MARK: - Constants

  CONST_SECTION

  .p2align 4
LOCAL(encode_constants):
  // +0: The hex digits.
  .ascii "0123456789ABCDEF"
  // Shuffles of the hex digits, where index k is the high nibble digit of byte k, and index
  // 16 + k is its low nibble digit.
  // +16: string[0..<16]
  .byte 0, 16, 1, 17, 2, 18, 3, 19, 0xFF, 4, 20, 5, 21, 0xFF, 6, 22
  // +32: string[16..<32]
  .byte 7, 23, 0xFF, 8, 24, 9, 25, 0xFF, 10, 26, 11, 27, 12, 28, 13, 29
  // +48: string[32..<36]
  .byte 14, 30, 15, 31, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF

  .p2align 4
LOCAL(decode_constants):
  // +0, +16: The gather indices of the high and low nibble digits in the canonical layout, where
  // indices 32-35 are string[32..<36].
  .byte  0,  2,  4,  6,  9, 11, 14, 16, 19, 21, 24, 26, 28, 30, 32, 34
  .byte  1,  3,  5,  7, 10, 12, 15, 17, 20, 22, 25, 27, 29, 31, 33, 35
  // +32: Digit classes by high nibble. Bit 0 is 0-9 (0x3_), bit 1 is A-F and a-f (0x4_ and 0x6_),
  // and the upper nibble is the offset of a letter's value from its low nibble.
  .byte 0x00, 0x00, 0x00, 0x01, 0x92, 0x00, 0x92, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
  // +48: Digit classes by low nibble.
  .byte 0x01, 0x03, 0x03, 0x03, 0x03, 0x03, 0x03, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
  // +64: The string positions that may hold hyphens. (Out of range indices are ignored.)
  .byte 8, 13, 18, 23, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF
  // +80: The bit of each hyphen position in the hyphen mask.
  .byte 1, 2, 4, 8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  // +96: The expected string length for each hyphen mask (32 + the number of hyphens).
  .byte 32, 33, 33, 34, 33, 34, 34, 35, 33, 34, 34, 35, 34, 35, 35, 36
  // +112: For each hyphen mask, the gather indices of the high nibble digits followed by the low
  // nibble digits. Indices 0-31 are string[0..<32], and indices 32-47 are
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
