#include <stdint.h>

// This file has some exciting magic to get Rust code linking in a cc_binary.
// The Rust compiler generates some similar symbol aliases when it links, so we
// have to do it manually.
//
// It is intended to be used in rust_toolchain.allocator_library.
//
// https://github.com/rust-lang/rust/blob/master/library/alloc/src/alloc.rs is
// the best source of docs I've found on these functions.
// https://doc.rust-lang.org/std/alloc/index.html talks about how this is
// intended to be used.
//
// Also note
// https://rust-lang.github.io/unsafe-code-guidelines/layout/scalars.html for
// the sizes of the various integer types.
//
// This file strongly assumes that the default allocator is used. It will
// not work with any other allocated switched in via `#[global_allocator]`.

uint8_t *__rdl_alloc(uintptr_t size, uintptr_t align);
uint8_t *__rust_alloc(uintptr_t size, uintptr_t align) {
  return __rdl_alloc(size, align);
}
void __rdl_dealloc(uint8_t *ptr, uintptr_t size, uintptr_t align);
void __rust_dealloc(uint8_t *ptr, uintptr_t size, uintptr_t align) {
  __rdl_dealloc(ptr, size, align);
}
uint8_t *__rdl_realloc(uint8_t *ptr, uintptr_t old_size, uintptr_t align,
                       uintptr_t new_size);
uint8_t *__rust_realloc(uint8_t *ptr, uintptr_t old_size, uintptr_t align,
                        uintptr_t new_size) {
  return __rdl_realloc(ptr, old_size, align, new_size);
}
uint8_t *__rdl_alloc_zeroed(uintptr_t size, uintptr_t align);
uint8_t *__rust_alloc_zeroed(uintptr_t size, uintptr_t align) {
  return __rdl_alloc_zeroed(size, align);
}
void __rdl_oom(uintptr_t size, uintptr_t align);
void __rust_alloc_error_handler(uintptr_t size, uintptr_t align) {
  __rdl_oom(size, align);
}