cmake_minimum_required(VERSION 3.22.1)
project(dxtr_card_scan_processor LANGUAGES C)

if(NOT ANDROID)
  message(FATAL_ERROR "dxtr_card_scan Android CMake build requires the Android toolchain")
endif()

if(ANDROID_ABI STREQUAL "arm64-v8a")
  set(RUST_TARGET "aarch64-linux-android")
  set(RUST_LINKER_ENV "CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER")
  set(RUST_CLANG_TRIPLE "aarch64-linux-android")
elseif(ANDROID_ABI STREQUAL "armeabi-v7a")
  set(RUST_TARGET "armv7-linux-androideabi")
  set(RUST_LINKER_ENV "CARGO_TARGET_ARMV7_LINUX_ANDROIDEABI_LINKER")
  set(RUST_CLANG_TRIPLE "armv7a-linux-androideabi")
elseif(ANDROID_ABI STREQUAL "x86_64")
  set(RUST_TARGET "x86_64-linux-android")
  set(RUST_LINKER_ENV "CARGO_TARGET_X86_64_LINUX_ANDROID_LINKER")
  set(RUST_CLANG_TRIPLE "x86_64-linux-android")
else()
  message(FATAL_ERROR "Unsupported Android ABI: ${ANDROID_ABI}")
endif()

string(REPLACE "android-" "" ANDROID_API_LEVEL "${ANDROID_PLATFORM}")
get_filename_component(NDK_BIN_DIR "${CMAKE_C_COMPILER}" DIRECTORY)
set(RUST_LINKER "${NDK_BIN_DIR}/${RUST_CLANG_TRIPLE}${ANDROID_API_LEVEL}-clang")

if(NOT EXISTS "${RUST_LINKER}")
  message(FATAL_ERROR "Rust Android linker not found: ${RUST_LINKER}")
endif()

set(RUST_MANIFEST "${CMAKE_CURRENT_LIST_DIR}/../rust/Cargo.toml")
set(RUST_TARGET_DIR "${CMAKE_CURRENT_BINARY_DIR}/rust-target")
set(RUST_LIBRARY "${RUST_TARGET_DIR}/${RUST_TARGET}/release/libdxtr_card_scan_processor.a")

add_custom_command(
  OUTPUT "${RUST_LIBRARY}"
  COMMAND rustup target add "${RUST_TARGET}"
  COMMAND ${CMAKE_COMMAND} -E env
          "${RUST_LINKER_ENV}=${RUST_LINKER}"
          "CARGO_TARGET_DIR=${RUST_TARGET_DIR}"
          cargo build --manifest-path "${RUST_MANIFEST}" --target "${RUST_TARGET}" --release
  DEPENDS
          "${CMAKE_CURRENT_LIST_DIR}/../rust/src/contrast_region.rs"
          "${CMAKE_CURRENT_LIST_DIR}/../rust/src/detection.rs"
          "${CMAKE_CURRENT_LIST_DIR}/../rust/src/ffi.rs"
          "${CMAKE_CURRENT_LIST_DIR}/../rust/src/lib.rs"
          "${CMAKE_CURRENT_LIST_DIR}/../rust/src/model.rs"
          "${CMAKE_CURRENT_LIST_DIR}/../rust/src/processor.rs"
          "${CMAKE_CURRENT_LIST_DIR}/../rust/src/quality.rs"
          "${CMAKE_CURRENT_LIST_DIR}/../rust/src/quality_ffi.rs"
          "${CMAKE_CURRENT_LIST_DIR}/../rust/src/warp.rs"
          "${RUST_MANIFEST}"
  WORKING_DIRECTORY "${CMAKE_CURRENT_LIST_DIR}/.."
  VERBATIM
)

add_custom_target(dxtr_card_scan_rust_build DEPENDS "${RUST_LIBRARY}")

add_library(dxtr_card_scan_rust STATIC IMPORTED GLOBAL)
set_target_properties(dxtr_card_scan_rust PROPERTIES IMPORTED_LOCATION "${RUST_LIBRARY}")
add_dependencies(dxtr_card_scan_rust dxtr_card_scan_rust_build)

add_library(dxtr_card_scan_processor SHARED src/main/c/bridge.c)
add_dependencies(dxtr_card_scan_processor dxtr_card_scan_rust_build)
target_link_libraries(
  dxtr_card_scan_processor
  PRIVATE
  "-Wl,--whole-archive"
  dxtr_card_scan_rust
  "-Wl,--no-whole-archive"
  log
  dl
  m
)
