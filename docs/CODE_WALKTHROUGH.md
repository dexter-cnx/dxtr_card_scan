# Code Walkthrough

This document tracks the implementation as the package evolves.

## 0.1 Capture foundation

`NormalizedRect`, `PreviewGeometry`, and `CapturedImageTransform` keep Camera/Gallery geometry in normalized source-image coordinates. `CaptureFrame`, orientation policy, Camera controls, Gallery crop, and `CardScanTheme` remain Flutter-owned.

## 0.2 Rust processing

### `rust/src/model.rs`
`ProcessorOptions` covers orientation, raw ROI, auto detection/manual quad, bounded warp size, OCR enhancement, grayscale, resize, and JPEG/PNG output.

### `rust/src/processor.rs`
Pipeline:
1. decode
2. quantize raw ROI
3. normalize orientation
4. rotate/crop ROI
5. detect or consume perspective quad
6. perspective warp/crop
7. optional OCR enhancement/grayscale
8. optional resize
9. encode

### `rust/src/detection.rs`
Deterministic classical-CV detector: grayscale, blur, Sobel, adaptive threshold, flat-image rejection, connected components, convex hull, distinct-corner quad approximation, scoring.

### `rust/src/warp.rs`
Deterministic projective rectification with cyclic-corner handling, long-edge-first orientation, bilinear sampling, allocation bounds, and degenerate/singular rejection.

### `rust/src/ffi.rs`
Stable C ABI:
- `card_scan_process`
- `card_scan_result_free`

Input is encoded image bytes plus UTF-8 JSON options. Output/error memory remains Rust-owned until the result is freed.

## 0.2 Dart FFI boundary

### `lib/src/processor/card_scan_processor_options.dart`
Public DTOs mirror the Rust JSON contract without exposing Rust implementation types:
- `CardScanProcessorOptions`
- `ProcessorPoint`
- `ProcessorQuad`
- `ProcessorOutputFormat`

Manual `perspectiveQuad` coordinates refer to the working image after orientation normalization and optional ROI crop.

### `lib/src/processor/card_scan_processor.dart`
`CardScanProcessor` owns Dart-side FFI allocation/copy/free behavior. It exposes `processBytes()` and `processFile()`, converts options to UTF-8 JSON, copies Rust output before freeing the native result, and maps nonzero Rust statuses to `CardScanProcessorException`.

Library loading:
- Android: `DynamicLibrary.open('libdxtr_card_scan_processor.so')`
- iOS/macOS: `DynamicLibrary.process()` because the Rust static library is linked into the application process.

## Native packaging

### Android
`android/CMakeLists.txt` maps `ANDROID_ABI` to the matching Rust target and uses the NDK compiler supplied by CMake as Cargo's linker. Cargo builds the Rust staticlib; CMake force-links it into `libdxtr_card_scan_processor.so` so exported C ABI symbols remain available to Dart FFI. No binary is committed.

### iOS / macOS
The podspecs add a before-compile Rust build phase. `tool/build_rust_darwin.sh` maps `PLATFORM_NAME`/`ARCHS` to Apple Rust targets, builds each active architecture, uses `lipo` when a universal library is required, and places the result under the pod build directory. `OTHER_LDFLAGS -force_load` keeps the Rust C ABI symbols from being stripped.

## Validation tooling

`make install-hooks` installs the tracked pre-push guard. `make ci` covers Flutter gates plus Rust format, Clippy, and tests. PR4 additionally relies on the Android example build as the first automated Gradle -> CMake -> Cargo -> APK integration gate.

## Naming rule

`Dxtr`/`dxtr` belongs only to package/repository identity. Public Dart domain classes remain neutral.

## Validation status

- v0.1 physical-device validation passed 2026-08-22.
- PR #3 Rust foundation merged.
- PR #4 deterministic quad detection merged.
- PR #5 perspective warp/OCR enhancement merged.
- PR4 Dart FFI/native packaging is in progress; physical native-processing validation is the next manual gate after automated CI stabilizes.
