#include <stdint.h>

// The Rust static library is linked with --whole-archive so its exported C ABI
// symbols remain available to Dart FFI. This translation unit gives CMake a
// concrete shared-library target for Android packaging.
__attribute__((visibility("default")))
__attribute__((used))
uint32_t card_scan_bridge_abi_version(void) {
  return 1u;
}
