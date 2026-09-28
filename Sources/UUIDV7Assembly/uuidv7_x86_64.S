// AVX2 implementations of UUIDV7 string encoding and decoding for x86-64.
// See include/UUIDV7Assembly.h for the C interface.
//
// Not every x86-64 CPU supports AVX2, so callers must check uuidv7_is_supported before calling
// these functions, and use the portable Swift implementation otherwise. This file assembles to
// nothing on other architectures, and on Windows, which has a different calling convention and
// always uses the portable Swift implementation.

#if defined(__x86_64__) && defined(__LP64__) && !defined(_WIN32)

  .intel_syntax noprefix

// MARK: - Platform Macros

#if defined(__APPLE__)
  #define SYMBOL(name) _##name
  #define LOCAL(name) L##name
  #define HIDDEN(name) .private_extern name
  #define CONST_SECTION .section __TEXT,__const
  #define FUNCTION_TYPE(name)
  #define FUNCTION_SIZE(name)
  #define OBJECT_TYPE(name, byte_count)
#else
  #define SYMBOL(name) name
  #define LOCAL(name) .L##name
  #define HIDDEN(name) .hidden name
  #define CONST_SECTION .section .rodata
  #define FUNCTION_TYPE(name) .type name, @function
  #define FUNCTION_SIZE(name) .size name, .-name
  #define OBJECT_TYPE(name, byte_count) .type name, @object; .size name, byte_count
#endif

#if defined(__CET__) && (__CET__ & 1)
  #define FUNCTION_LANDING_PAD endbr64
#else
  #define FUNCTION_LANDING_PAD
#endif

#define BEGIN_FUNCTION(name) \
  .globl SYMBOL(name); \
  FUNCTION_TYPE(SYMBOL(name)); \
  .p2align 4; \
  SYMBOL(name):; \
  .cfi_startproc; \
  FUNCTION_LANDING_PAD

#define END_FUNCTION(name) \
  .cfi_endproc; \
  FUNCTION_SIZE(SYMBOL(name))

  .text

// MARK: - CPU Support

// bool uuidv7_detect_cpu_support(void)
//
// Returns whether the CPU and OS support AVX2, and caches the result in uuidv7_cpu_support.
  HIDDEN(SYMBOL(uuidv7_detect_cpu_support))
BEGIN_FUNCTION(uuidv7_detect_cpu_support)
  push rbx                                // cpuid overwrites rbx, which is callee saved.
  .cfi_adjust_cfa_offset 8
  .cfi_rel_offset rbx, 0
  xor esi, esi                            // esi = Whether AVX2 is supported.
  xor eax, eax
  cpuid
  cmp eax, 7
  jb LOCAL(detect_done)                   // The CPU can't describe AVX2 support.

  // The CPU must support AVX and XSAVE, and the OS must preserve the XMM and YMM registers.
  mov eax, 1
  cpuid
  and ecx, 0x18000000                     // OSXSAVE (bit 27) and AVX (bit 28)
  cmp ecx, 0x18000000
  jne LOCAL(detect_done)
  xor ecx, ecx
  xgetbv                                  // eax = XCR0[0..<32]
  and eax, 0x6                            // XMM (bit 1) and YMM (bit 2) state
  cmp eax, 0x6
  jne LOCAL(detect_done)

  mov eax, 7
  xor ecx, ecx
  cpuid
  shr ebx, 5                              // AVX2 (bit 5)
  and ebx, 1
  mov esi, ebx

LOCAL(detect_done):
  lea eax, [rsi + rsi - 1]                // 1 when supported, and -1 otherwise.
  mov byte ptr [rip + SYMBOL(uuidv7_cpu_support)], al
  mov eax, esi
  pop rbx
  .cfi_adjust_cfa_offset -8
  .cfi_restore rbx
  ret
END_FUNCTION(uuidv7_detect_cpu_support)

// MARK: - Encoding

// void uuidv7_encode(const void *uuid, void *string)
//
// rdi: The 16 UUID bytes.
// rsi: The 36 byte buffer for the uppercase hyphenated string.
BEGIN_FUNCTION(uuidv7_encode)
  vbroadcasti128 ymm0, xmmword ptr [rdi]  // Both lanes hold the 16 UUID bytes.
  vmovdqa ymm2, ymmword ptr [rip + LOCAL(nibble_mask)]
  vmovdqa ymm3, ymmword ptr [rip + LOCAL(hex_digits)]
  vpsrlw ymm1, ymm0, 4
  vpand ymm1, ymm1, ymm2
  vpand ymm0, ymm0, ymm2
  vpshufb ymm1, ymm3, ymm1                // Hex digits of the high nibbles.
  vpshufb ymm0, ymm3, ymm0                // Hex digits of the low nibbles.

  // string[32..<36] is the end of the interleaved digits of bytes 8..<16, so this stores all of
  // them to string[20..<36], and the store of string[0..<32] below overwrites the rest.
  vpunpckhbw xmm2, xmm1, xmm0
  vmovdqu xmmword ptr [rsi + 20], xmm2

  // Each shuffle places the digits of one nibble, and its out of range indices leave zeros for the
  // digits of the other nibble and the hyphens.
  vpshufb ymm1, ymm1, ymmword ptr [rip + LOCAL(encode_high_shuffle)]
  vpshufb ymm0, ymm0, ymmword ptr [rip + LOCAL(encode_low_shuffle)]
  vpor ymm0, ymm0, ymm1
  vpor ymm0, ymm0, ymmword ptr [rip + LOCAL(hyphens)]
  vmovdqu ymmword ptr [rsi], ymm0         // string[0..<32]
  vzeroupper
  ret
END_FUNCTION(uuidv7_encode)

// MARK: - Decoding

// bool uuidv7_decode(const void *string, size_t length, void *uuid)
//
// rdi: The UTF-8 string.
// rsi: The length of the string in bytes.
// rdx: The 16 byte buffer for the UUID, which is only written to on success.
//
// This accepts exactly what the portable Swift implementation accepts: 32 case-insensitive hex
// digits, with hyphens allowed at any subset of the string positions 8, 13, 18, and 23. Therefore,
// valid strings are 32-36 bytes long, and have exactly (length - 32) hyphens.
//
// Every layout loads string[0..<32], which contains all of the hyphen positions, and then moves
// string[32..<length] into the hyphen positions that hold hyphens. The canonical 36 byte layout
// does this with fixed indices, the 32 byte layout has nothing to move, and other layouts first
// work out which hyphens are present.
BEGIN_FUNCTION(uuidv7_decode)
  cmp rsi, 36
  jne LOCAL(decode_other_layouts)

  vmovdqu ymm0, ymmword ptr [rdi]         // string[0..<32]
  vpbroadcastd ymm1, dword ptr [rdi + 32] // string[32..<36] in every dword
  vmovdqa ymm3, ymmword ptr [rip + LOCAL(hyphen_positions)]

  // ymm2 = 0xFF in the lanes of hyphen positions that don't hold hyphens.
  vpcmpeqb ymm2, ymm0, ymmword ptr [rip + LOCAL(hyphens)]
  vpandn ymm2, ymm2, ymm3

  // The hyphen positions are 0, 1, 2, and 3 mod 4, so each one already has its digit in ymm1.
  vpblendvb ymm0, ymm0, ymm1, ymm3
  lea rax, [rip + LOCAL(canonical_gather_indices)]

// ymm0 = 32 characters that must all be hex digits, ymm2 = nonzero in lanes that are otherwise
// invalid, and rax = the gather indices of the layout.
LOCAL(decode_digits):
  // A character is a hex digit when the classes of its high and low nibbles intersect. The high
  // nibble class of a digit is also the offset of its value from its character.
  vpsrlw ymm4, ymm0, 4
  vpand ymm4, ymm4, ymmword ptr [rip + LOCAL(nibble_mask)]
  vmovdqa ymm5, ymmword ptr [rip + LOCAL(high_nibble_classes)]
  vmovdqa ymm6, ymmword ptr [rip + LOCAL(low_nibble_classes)]
  vpshufb ymm4, ymm5, ymm4
  vpshufb ymm5, ymm6, ymm0                // (Non-ASCII characters have no class.)
  vpand ymm5, ymm5, ymm4                  // Nonzero in lanes that hold hex digits.
  vpaddb ymm0, ymm0, ymm4                 // Digit values.

  // Every lane must be valid.
  vpxor xmm6, xmm6, xmm6
  vpcmpeqb ymm5, ymm5, ymm6
  vpor ymm5, ymm5, ymm2
  vpmovmskb ecx, ymm5
  test ecx, ecx
  jnz LOCAL(decode_failure)

  // Each lane places the values of its digits at the indices of their bytes, and the digits of each
  // byte come from exactly one of the lanes.
  vpshufb ymm1, ymm0, ymmword ptr [rax]   // High nibble values.
  vpshufb ymm0, ymm0, ymmword ptr [rax + 32] // Low nibble values.
  vpsllw ymm1, ymm1, 4
  vpor ymm0, ymm0, ymm1
  vextracti128 xmm1, ymm0, 1
  vpor xmm0, xmm0, xmm1
  vmovdqu xmmword ptr [rdx], xmm0
  mov eax, 1
  vzeroupper
  ret

LOCAL(decode_other_layouts):
  cmp rsi, 32
  jne LOCAL(decode_partially_hyphenated_layout)

  // The digits are already in place, and any hyphens fail the digit check.
  vmovdqu ymm0, ymmword ptr [rdi]         // string[0..<32]
  vpxor xmm2, xmm2, xmm2
  lea rax, [rip + LOCAL(gather_indices)]  // The gather indices of hyphen mask 0b0000.
  jmp LOCAL(decode_digits)

LOCAL(decode_partially_hyphenated_layout):
  lea rax, [rsi - 33]
  cmp rax, 2
  ja LOCAL(decode_failure)                // length < 33 || length > 35
  vmovdqu ymm0, ymmword ptr [rdi]         // string[0..<32]
  vpbroadcastd ymm1, dword ptr [rdi + rsi - 4] // string[(length - 4)..<length] in every dword

  // ymm3 = 0xFF in the lanes of hyphen positions that hold hyphens, and eax = a 4-bit mask of them.
  vpcmpeqb ymm3, ymm0, ymmword ptr [rip + LOCAL(hyphens)]
  vpand ymm3, ymm3, ymmword ptr [rip + LOCAL(hyphen_positions)]
  vpmovmskb eax, ymm3
  imul eax, eax, 0x1111                   // Moves bits 8, 13, 18, and 23 to bits 20-23.
  shr eax, 20
  and eax, 0xF

  // The hyphens must account for every byte beyond the 32 hex digits.
  lea rcx, [rip + LOCAL(decode_lengths)]
  movzx ecx, byte ptr [rcx + rax]
  cmp rcx, rsi
  jne LOCAL(decode_failure)

  // Move string[32..<length] into the hyphen positions. Hyphens anywhere else then fail the digit
  // check.
  mov ecx, eax
  shl ecx, 4
  lea r8, [rip + LOCAL(tail_indices)]
  vbroadcasti128 ymm2, xmmword ptr [r8 + rcx]
  vpshufb ymm1, ymm1, ymm2
  vpblendvb ymm0, ymm0, ymm1, ymm3

  shl eax, 6
  lea rcx, [rip + LOCAL(gather_indices)]
  add rax, rcx
  vpxor xmm2, xmm2, xmm2
  jmp LOCAL(decode_digits)

LOCAL(decode_failure):
  xor eax, eax
  vzeroupper
  ret
END_FUNCTION(uuidv7_decode)

// MARK: - CPU Support State

  .data

// signed char uuidv7_cpu_support
//
// 0 until uuidv7_detect_cpu_support runs, then 1 when the CPU supports AVX2, and -1 otherwise.
  .globl SYMBOL(uuidv7_cpu_support)
  HIDDEN(SYMBOL(uuidv7_cpu_support))
  OBJECT_TYPE(SYMBOL(uuidv7_cpu_support), 1)
SYMBOL(uuidv7_cpu_support):
  .byte 0

// MARK: - Constants

  CONST_SECTION

  .p2align 5
LOCAL(hex_digits):
  .ascii "0123456789ABCDEF0123456789ABCDEF"
LOCAL(nibble_mask):
  .fill 32, 1, 0x0F

// The hyphens of a canonical string, and the lanes of the hyphen positions.
LOCAL(hyphens):
  .byte 0, 0, 0, 0, 0, 0, 0, 0, 0x2D, 0, 0, 0, 0, 0x2D, 0, 0
  .byte 0, 0, 0x2D, 0, 0, 0, 0, 0x2D, 0, 0, 0, 0, 0, 0, 0, 0
LOCAL(hyphen_positions):
  .byte 0, 0, 0, 0, 0, 0, 0, 0, 0xFF, 0, 0, 0, 0, 0xFF, 0, 0
  .byte 0, 0, 0xFF, 0, 0, 0, 0, 0xFF, 0, 0, 0, 0, 0, 0, 0, 0

// Shuffles of the hex digits of the high and low nibbles, where index k is the digit of byte k in
// either lane. Lane 0 is string[0..<16], and lane 1 is string[16..<32].
LOCAL(encode_high_shuffle):
  .byte 0, 0x80, 1, 0x80, 2, 0x80, 3, 0x80, 0x80, 4, 0x80, 5, 0x80, 0x80, 6, 0x80
  .byte 7, 0x80, 0x80, 8, 0x80, 9, 0x80, 0x80, 10, 0x80, 11, 0x80, 12, 0x80, 13, 0x80
LOCAL(encode_low_shuffle):
  .byte 0x80, 0, 0x80, 1, 0x80, 2, 0x80, 3, 0x80, 0x80, 4, 0x80, 5, 0x80, 0x80, 6
  .byte 0x80, 7, 0x80, 0x80, 8, 0x80, 9, 0x80, 0x80, 10, 0x80, 11, 0x80, 12, 0x80, 13

// Digit classes by high nibble, which are the offsets of digit values from their characters
// (-'0', -('A' - 10), and -('a' - 10)). All of them have bit 7 set, and only the offset of 0-9
// (0x3_) has bit 4 set.
LOCAL(high_nibble_classes):
  .byte 0, 0, 0, 0xD0, 0xC9, 0, 0xA9, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .byte 0, 0, 0, 0xD0, 0xC9, 0, 0xA9, 0, 0, 0, 0, 0, 0, 0, 0, 0
// Digit classes by low nibble, where bit 4 is 0-9, and bit 7 is 1-6 (A-F and a-f).
LOCAL(low_nibble_classes):
  .byte 0x10, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x10, 0x10, 0x10, 0, 0, 0, 0, 0, 0
  .byte 0x10, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x10, 0x10, 0x10, 0, 0, 0, 0, 0, 0

// The expected string length for each hyphen mask (32 + the number of hyphens).
LOCAL(decode_lengths):
  .byte 32, 33, 33, 34, 33, 34, 34, 35, 33, 34, 34, 35, 34, 35, 35, 36

// For each hyphen mask, the indices of string[32..<length] in the last 4 bytes of the string, at
// the lanes of the hyphen positions that they move into. Both lanes use the same indices, and the
// hyphen positions are at 8 and 13 in lane 0, and at 2 and 7 in lane 1.
  .p2align 4
LOCAL(tail_indices):
  .byte 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80 // 0b0000
  .byte 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,    3, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80 // 0b0001
  .byte 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,    3, 0x80, 0x80 // 0b0010
  .byte 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,    2, 0x80, 0x80, 0x80, 0x80,    3, 0x80, 0x80 // 0b0011
  .byte 0x80, 0x80,    3, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80 // 0b0100
  .byte 0x80, 0x80,    3, 0x80, 0x80, 0x80, 0x80, 0x80,    2, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80 // 0b0101
  .byte 0x80, 0x80,    3, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,    2, 0x80, 0x80 // 0b0110
  .byte 0x80, 0x80,    3, 0x80, 0x80, 0x80, 0x80, 0x80,    1, 0x80, 0x80, 0x80, 0x80,    2, 0x80, 0x80 // 0b0111
  .byte 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,    3, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80 // 0b1000
  .byte 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,    3,    2, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80 // 0b1001
  .byte 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,    3, 0x80, 0x80, 0x80, 0x80, 0x80,    2, 0x80, 0x80 // 0b1010
  .byte 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,    3,    1, 0x80, 0x80, 0x80, 0x80,    2, 0x80, 0x80 // 0b1011
  .byte 0x80, 0x80,    2, 0x80, 0x80, 0x80, 0x80,    3, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80 // 0b1100
  .byte 0x80, 0x80,    2, 0x80, 0x80, 0x80, 0x80,    3,    1, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80 // 0b1101
  .byte 0x80, 0x80,    2, 0x80, 0x80, 0x80, 0x80,    3, 0x80, 0x80, 0x80, 0x80, 0x80,    1, 0x80, 0x80 // 0b1110
  .byte 0x80, 0x80,    2, 0x80, 0x80, 0x80, 0x80,    3,    0, 0x80, 0x80, 0x80, 0x80,    1, 0x80, 0x80 // 0b1111

// For each hyphen mask, the gather indices of the high nibble digits followed by the low nibble
// digits, after moving string[32..<length] into the hyphen positions. In each lane, index k is the
// lane's digit for byte k, or 0x80 when the digit is in the other lane.
  .p2align 6
LOCAL(gather_indices):
  .byte    0,    2,    4,    6,    8,   10,   12,   14, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80 // 0b0000 high
  .byte 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,    0,    2,    4,    6,    8,   10,   12,   14
  .byte    1,    3,    5,    7,    9,   11,   13,   15, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80 // 0b0000 low
  .byte 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,    1,    3,    5,    7,    9,   11,   13,   15
  .byte    0,    2,    4,    6,    9,   11,   13,   15, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80 // 0b0001 high
  .byte 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,    1,    3,    5,    7,    9,   11,   13,   15
  .byte    1,    3,    5,    7,   10,   12,   14, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,    8 // 0b0001 low
  .byte 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,    0,    2,    4,    6,    8,   10,   12,   14, 0x80
  .byte    0,    2,    4,    6,    8,   10,   12,   15, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80 // 0b0010 high
  .byte 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,    1,    3,    5,    7,    9,   11,   13,   15
  .byte    1,    3,    5,    7,    9,   11,   14, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,   13 // 0b0010 low
  .byte 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,    0,    2,    4,    6,    8,   10,   12,   14, 0x80
  .byte    0,    2,    4,    6,    9,   11,   14, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,    8 // 0b0011 high
  .byte 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,    0,    2,    4,    6,    8,   10,   12,   14, 0x80
  .byte    1,    3,    5,    7,   10,   12,   15, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,   13 // 0b0011 low
  .byte 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,    1,    3,    5,    7,    9,   11,   13,   15, 0x80
  .byte    0,    2,    4,    6,    8,   10,   12,   14, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80 // 0b0100 high
  .byte 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,    0,    3,    5,    7,    9,   11,   13,   15
  .byte    1,    3,    5,    7,    9,   11,   13,   15, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80 // 0b0100 low
  .byte 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,    1,    4,    6,    8,   10,   12,   14,    2
  .byte    0,    2,    4,    6,    9,   11,   13,   15, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,    8 // 0b0101 high
  .byte 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,    1,    4,    6,    8,   10,   12,   14, 0x80
  .byte    1,    3,    5,    7,   10,   12,   14, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80 // 0b0101 low
  .byte 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,    0,    3,    5,    7,    9,   11,   13,   15,    2
  .byte    0,    2,    4,    6,    8,   10,   12,   15, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,   13 // 0b0110 high
  .byte 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,    1,    4,    6,    8,   10,   12,   14, 0x80
  .byte    1,    3,    5,    7,    9,   11,   14, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80 // 0b0110 low
  .byte 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,    0,    3,    5,    7,    9,   11,   13,   15,    2
  .byte    0,    2,    4,    6,    9,   11,   14, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,   13 // 0b0111 high
  .byte 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,    0,    3,    5,    7,    9,   11,   13,   15, 0x80
  .byte    1,    3,    5,    7,   10,   12,   15, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,    8, 0x80 // 0b0111 low
  .byte 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,    1,    4,    6,    8,   10,   12,   14, 0x80,    2
  .byte    0,    2,    4,    6,    8,   10,   12,   14, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80 // 0b1000 high
  .byte 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,    0,    2,    4,    6,    9,   11,   13,   15
  .byte    1,    3,    5,    7,    9,   11,   13,   15, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80 // 0b1000 low
  .byte 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,    1,    3,    5,    8,   10,   12,   14,    7
  .byte    0,    2,    4,    6,    9,   11,   13,   15, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,    8 // 0b1001 high
  .byte 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,    1,    3,    5,    8,   10,   12,   14, 0x80
  .byte    1,    3,    5,    7,   10,   12,   14, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80 // 0b1001 low
  .byte 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,    0,    2,    4,    6,    9,   11,   13,   15,    7
  .byte    0,    2,    4,    6,    8,   10,   12,   15, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,   13 // 0b1010 high
  .byte 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,    1,    3,    5,    8,   10,   12,   14, 0x80
  .byte    1,    3,    5,    7,    9,   11,   14, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80 // 0b1010 low
  .byte 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,    0,    2,    4,    6,    9,   11,   13,   15,    7
  .byte    0,    2,    4,    6,    9,   11,   14, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,   13 // 0b1011 high
  .byte 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,    0,    2,    4,    6,    9,   11,   13,   15, 0x80
  .byte    1,    3,    5,    7,   10,   12,   15, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,    8, 0x80 // 0b1011 low
  .byte 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,    1,    3,    5,    8,   10,   12,   14, 0x80,    7
  .byte    0,    2,    4,    6,    8,   10,   12,   14, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80 // 0b1100 high
  .byte 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,    0,    3,    5,    8,   10,   12,   14,    2
  .byte    1,    3,    5,    7,    9,   11,   13,   15, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80 // 0b1100 low
  .byte 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,    1,    4,    6,    9,   11,   13,   15,    7
  .byte    0,    2,    4,    6,    9,   11,   13,   15, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80 // 0b1101 high
  .byte 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,    1,    4,    6,    9,   11,   13,   15,    2
  .byte    1,    3,    5,    7,   10,   12,   14, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,    8, 0x80 // 0b1101 low
  .byte 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,    0,    3,    5,    8,   10,   12,   14, 0x80,    7
  .byte    0,    2,    4,    6,    8,   10,   12,   15, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80 // 0b1110 high
  .byte 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,    1,    4,    6,    9,   11,   13,   15,    2
  .byte    1,    3,    5,    7,    9,   11,   14, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,   13, 0x80 // 0b1110 low
  .byte 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,    0,    3,    5,    8,   10,   12,   14, 0x80,    7
LOCAL(canonical_gather_indices):
  .byte    0,    2,    4,    6,    9,   11,   14, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,    8, 0x80 // 0b1111 high
  .byte 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,    0,    3,    5,    8,   10,   12,   14, 0x80,    2
  .byte    1,    3,    5,    7,   10,   12,   15, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,   13, 0x80 // 0b1111 low
  .byte 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80,    1,    4,    6,    9,   11,   13,   15, 0x80,    7

// MARK: - Object File Metadata

#if defined(__APPLE__)
  .subsections_via_symbols
#elif defined(__CET__)
  // Marks the functions above as compatible with IBT (they have landing pads) and shadow stacks
  // (they always return to their callers).
  .pushsection .note.gnu.property, "a"
  .p2align 3
  .long 4                                 // Name size.
  .long 16                                // Descriptor size.
  .long 5                                 // NT_GNU_PROPERTY_TYPE_0
  .asciz "GNU"
  .long 0xC0000002                        // GNU_PROPERTY_X86_FEATURE_1_AND
  .long 4                                 // Property size.
  .long __CET__                           // GNU_PROPERTY_X86_FEATURE_1_IBT (1) | _SHSTK (2)
  .long 0                                 // Padding.
  .popsection
#endif

#endif

// NB: Without this, linking this object into an ELF binary implies an executable stack, even on
// architectures where the rest of this file assembles to nothing.
#if defined(__ELF__)
  .section .note.GNU-stack, "", %progbits
#endif
