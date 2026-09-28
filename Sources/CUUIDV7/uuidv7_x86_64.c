#include "CUUIDV7.h"

// NB: This file compiles to nothing on other architectures, and on Windows, which always uses the
// portable Swift implementation.
#if defined(__x86_64__) && defined(__LP64__) && !defined(_WIN32)

#include <cpuid.h>

signed char uuidv7_cpu_support = 0;

// NB: xgetbv requires the xsave target feature, but it only runs once cpuid reports that the OS has
// enabled XSAVE.
__attribute__((target("xsave"))) bool uuidv7_detect_cpu_support(void) {
  unsigned int eax, ebx, ecx, edx;
  const unsigned int avx = bit_OSXSAVE | bit_AVX;

  // The CPU must support AVX and XSAVE, and the OS must preserve the XMM and YMM registers (bits 1
  // and 2 of XCR0).
  bool is_supported = __get_cpuid(1, &eax, &ebx, &ecx, &edx) && (ecx & avx) == avx
    && (_xgetbv(0) & 0x6) == 0x6 && __get_cpuid_count(7, 0, &eax, &ebx, &ecx, &edx)
    && (ebx & bit_AVX2) != 0;
  __atomic_store_n(&uuidv7_cpu_support, is_supported ? 1 : -1, __ATOMIC_RELAXED);
  return is_supported;
}

#endif
