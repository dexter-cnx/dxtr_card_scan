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
Deterministic projective rectification with cyclic-corner handling, long-edge-first orientation, source-top preservation, bilinear sampling, allocation bounds, and degenerate/singular rejection. Source-top preservation prevents a cyclic quad starting on the bottom edge from producing a 180-degree output flip.

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

### `lib/src/processor/card_scan_processor.dart`
`CardScanProcessor` owns Dart-side FFI allocation/copy/free behavior. It exposes `processBytes()` and `processFile()`, converts options to UTF-8 JSON, copies Rust output before freeing the native result, and maps nonzero Rust statuses to `CardScanProcessorException`.

Library loading:
- Android: `DynamicLibrary.open('libdxtr_card_scan_processor.so')`
- iOS/macOS: `DynamicLibrary.process()` because the Rust static library is linked into the application process.

## Native packaging

### Android
`android/CMakeLists.txt` maps `ANDROID_ABI` to the matching Rust target and uses the NDK compiler supplied by CMake as Cargo's linker. Cargo builds the Rust staticlib; CMake force-links it into `libdxtr_card_scan_processor.so` so exported C ABI symbols remain available to Dart FFI. No binary is committed.

### iOS / macOS
The podspecs add a before-compile Rust build phase. `tool/build_rust_darwin.sh` maps `PLATFORM_NAME`/`ARCHS` to Apple Rust targets, builds each active architecture, uses `lipo` when a universal library is required, and places the result under the pod build directory. The script phase declares the generated archive as an Xcode output, and consumer-target `OTHER_LDFLAGS -force_load` keeps the Rust C ABI symbols from being stripped.

## Integrated example structure

`example/lib/integrated_card_scan_demo.dart` is the default entrypoint and now only owns app/home navigation.

Dedicated files:
- `camera_scan_page.dart` — Camera UI + capture-frame flow
- `gallery_scan_page.dart` — Gallery picker/crop/scan UX
- `background_scan_tasks.dart` — isolate-backed image preparation and native processing
- `processed_preview_page.dart` — processed output rendering

### Background work

`background_scan_tasks.dart` uses `Isolate.run()` for two expensive operations:
1. image decode + EXIF `bakeOrientation()` + normalized JPEG write
2. synchronous Dart FFI -> Rust processor execution

This keeps Flutter animation/input responsive while decoding, detecting, warping, and encoding.

## Integrated Camera flow

Camera processing sequence:
1. preview through `CardCaptureView` with the existing ID-1 frame
2. keep zoom, flash off/auto/on, torch, Back, lifecycle handling, and orientation-aware shutter behavior
3. capture JPEG
4. normalize EXIF orientation on a worker isolate
5. resolve the same `CaptureFrame` against the camera viewport
6. map that viewport rectangle through `PreviewGeometry` to normalized source-image ROI coordinates
7. process the normalized image plus ROI on a worker isolate
8. run auto-detect and perspective warp only inside the frame ROI
9. apply OCR enhancement and render the processed bytes

Physical Android re-test passed this Camera flow, including orientation, frame ROI/warp behavior and controls.

## Gallery flow

Gallery sequence:
1. host picker returns an image
2. UI immediately shows `Preparing image…`
3. image decode + EXIF orientation bake runs on a worker isolate
4. `ImageCropView` displays that normalized file, so its ROI and Rust pixels use the same coordinate space
5. the Gallery route uses `PopScope` to block device/system back gestures while cropping; leaving is explicit through Close
6. `Scan selection` sends the selected ROI to a worker isolate
7. Rust crops ROI, auto-detects card edges inside it, perspective-warps the card, resizes/encodes, and returns JPEG bytes
8. Gallery preview preserves color by default; OCR enhancement remains optional rather than being forced on the scan preview

The crop should include the whole card so the detector still sees all four card edges inside the selected ROI.

## Validation tooling

`make install-hooks` installs the tracked pre-push guard. `make ci` covers Flutter gates plus Rust format, Clippy, and tests. PR #7 builds the default Android example as an arm64 Gradle -> CMake -> Cargo -> APK integration gate.

Generated build state such as `android/.cxx/` and `rust/target/` is ignored. `rust/Cargo.lock` remains committed for reproducible embedded native builds.

## Naming rule

`Dxtr`/`dxtr` belongs only to package/repository identity. Public Dart domain classes remain neutral.

## Validation status

- v0.1 physical-device validation passed 2026-08-22.
- PR #3 Rust foundation merged.
- PR #4 deterministic quad detection merged.
- PR #5 perspective warp/OCR enhancement merged.
- PR #6 Dart FFI/native packaging merged.
- PR #7 Android Camera physical validation passed after orientation/frame-ROI fixes.
- PR #7 iPhone 11 physical Camera/native-processing validation passed.
- Updated isolate-backed Gallery flow awaits Android/iPhone re-test.
- macOS native linkage remains to be validated.
