# Project Handoff

Last updated: 2026-08-22

## Project

Repository: `dexter-cnx/dxtr_card_scan`

`dxtr_card_scan` is an OCR-engine-agnostic Flutter/Dart SDK for card/document capture plus deterministic Rust preprocessing. Flutter owns camera/UI/preview geometry. Rust owns raster processing.

## Architecture rules

1. Core does not embed an OCR engine.
2. Rust does not own camera lifecycle/UI.
3. Preview/frame geometry is normalized before processing.
4. Rotation/mirroring is explicit.
5. File picking stays in the host/example.
6. Grayscale/OCR enhancement remains opt-in.
7. `Dxtr`/`dxtr` is reserved for package/repository identity; public Dart domain types remain neutral.
8. v0.2 detection remains deterministic classical CV.
9. `perspective_quad` is interpreted after orientation normalization and optional ROI crop.

## Current branch / PR

Branch: `agent/v0.2-dart-ffi-packaging`
PR: pending

## Completed

### v0.1 capture foundation

Merged and physical-device validated on 2026-08-22. Camera/Gallery navigation, portrait/landscape controls, flash, torch, pinch zoom, capture-frame alignment/padding, orientation policies, Gallery crop, and `CardScanTheme` passed on device.

### v0.2 PR1 — Rust processor foundation

Merged as PR #3. Includes JPEG/PNG decode, orientation normalization, pixel-stable ROI mapping/crop, optional grayscale/resize, encoding, stable C ABI, result ownership/free contract, and panic containment.

### v0.2 PR2 — quadrilateral detection

Merged as PR #4. Includes grayscale/blur/Sobel/adaptive threshold, flat-image rejection, connected components, convex hull, distinct-corner quad approximation, deterministic scoring, and 45-degree regression coverage.

### v0.2 PR3 — perspective warp / OCR enhancement

Merged as PR #5. Includes deterministic projective warp, bilinear sampling, cyclic-quad handling, long-edge-first output, bounded `warp_long_edge` (`2..=4096`), auto-detect/manual quad integration, conservative percentile OCR enhancement, and regression coverage for tiny images/allocation bounds.

## v0.2 PR4 — Dart FFI + native packaging

**In progress on `agent/v0.2-dart-ffi-packaging`.**

Current implementation:
- public `CardScanProcessor`
- `processBytes()` and `processFile()`
- Rust status/error mapping via `CardScanProcessorException`
- UTF-8 JSON option transport
- `CardScanProcessorOptions`, `ProcessorQuad`, `ProcessorPoint`, `ProcessorOutputFormat`
- Android loader uses `libdxtr_card_scan_processor.so`
- iOS/macOS loader uses `DynamicLibrary.process()`
- Flutter plugin metadata uses `ffiPlugin: true` for Android/iOS/macOS
- Android CMake maps `ANDROID_ABI` to Rust targets and links the Rust staticlib into the packaged shared library
- iOS/macOS CocoaPods build phase compiles Rust for active `PLATFORM_NAME` / `ARCHS`, creates a universal staticlib when necessary, and force-loads it so FFI symbols survive dead stripping
- processor option JSON contract unit tests

## Remaining before v0.2 physical validation

1. CI/analyze/unit-test cleanup for the new Dart/native packaging surface.
2. Android example build must prove Gradle -> CMake -> Rust -> APK packaging.
3. Add/validate example processor invocation for Camera/Gallery paths if automated gates are stable.
4. Validate iOS and macOS native linkage on Apple toolchains.
5. Physical-device test of decode -> ROI/detect -> warp -> enhancement -> output.

## Native build policy

The package keeps Flutter >=3.22 compatibility, so PR4 uses the legacy FFI-plugin platform build layout rather than requiring Flutter 3.38+ Native Assets build hooks. No native binary is committed to git.

`make install-hooks` installs the tracked pre-push guard. It runs Dart/Rust formatting and Rust validation locally before push.

## Documentation policy

Keep `docs/PROJECT_HANDOFF.md`, `docs/CODE_WALKTHROUGH.md`, and `docs/ROADMAP.md` synchronized for material architecture/native-processing changes.
