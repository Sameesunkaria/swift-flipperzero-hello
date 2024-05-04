// The symbols in this file are not exposed to a flipper app, so we need to provide
// them ourselves.

#include <furi_hal_resources.h>
#include <furi_hal_random.h>

// This not a correct implementation for posix_memalign but seems to work for the
// purposes of this example project.
//
// The returned pointer is not guaranteed to be a multiple of the requested alignment.
//
// To return correctly aligned memory, we could over-allocate and offset the pointer
// returned by `malloc`; but offsetting the pointer would prevent us from using `free`
// to free up the memory. Therefore, we can't correctly implement posix_memalign as a
// client of `malloc` and `free`. For a correct implementation, the memory allocator
// provided by the Flipper Zero firmware would need to be modified to support
// posix_memalign.
int posix_memalign(void** memptr, size_t alignment, size_t size) {
    void *mem = malloc(size);
    if (!mem) return 1;
    *memptr = mem;
    return 0;
}

// The following symbols are provided by libc and libc_nano but statically linking libc
// causes us to reference other symbols that aren't exposed to a flipper app. So I
// chose to provide these symbols here.

void arc4random_buf(void *buf, size_t nbytes) {
  furi_hal_random_fill_buf(buf, nbytes);
}

void __aeabi_memclr(void *dest, size_t n) {
  memset(dest, 0, n);
}

void __aeabi_memclr4(void *dest, size_t n) {
  memset(dest, 0, n);
}

void __aeabi_memclr8(void *dest, size_t n) {
  memset(dest, 0, n);
}
