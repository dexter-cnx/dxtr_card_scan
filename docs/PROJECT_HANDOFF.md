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

Branch: `agent/v0.2-example-native-flow`
PR: #7

## Completed

### v0.1 capture foundation

Merged and physical-device validated on 2026-08-22. Camera/Gallery navigation, portrait/landscape controls, flash, torch, pinch zoom, capture-frame alignment/padding, orientation policies, Gallery crop, and `CardScanTheme` passed on device.

### v0.2 PR1 — Rust processor foundation

Merged as PR #3. Includes JPEG/PNG decode, orientation normalization, pixel-stable ROI mapping/crop, optional grayscale/resize, encoding, stable C ABI, result ownership/free contract, and panic containment.

### v0.2 PR2 — quadrilateral detection

Merged as PR #4. Includes grayscale/blur/Sobel/adaptive threshold, flat-image rejection, connected components, convex hull, distinct-corner quad approximation, deterministic scoring, and 45-degree regression coverage.

### v0.2 PR3 — perspective warp / OCR enhancement

Merged as PR #5. Includes deterministic projective warp, bilinear sampling, cyclic-quad handling, long-edge-first output, bounded `warp_long_edge` (`2..=4096`), auto-detect/manual quad integration, conservative percentile OCR enhancement, and regression coverage for tiny images/allocation bounds.

### v0.2 PR4 — Dart FFI + native packaging

Merged as PR #6. Includes:
- public `CardScanProcessor`
- `processBytes()` and `processFile()`
- `CardScanProcessorException` native status/error mapping
- UTF-8 JSON option transport
- `CardScanProcessorOptions`, `ProcessorQuad`, `ProcessorPoint`, `ProcessorOutputFormat`
- Android `ffiPlugin` packaging through Gradle/CMake -> Cargo per ABI
- iOS/macOS `ffiPlugin` packaging through CocoaPods/Xcode -> Cargo per active architecture
- Darwin universal staticlib creation and consumer-target force-load linkage
- Flutter >=3.22 compatibility retained with AGP 7.4.2
- processor option JSON contract tests

## v0.2 PR5 — end-to-end native example validation

**In progress on `agent/v0.2-example-native-flow` as PR #7.**

Current implementation:
- dedicated `example/lib/native_processor_demo.dart` entrypoint
- Camera path: capture -> `CardScanProcessor.processFile()` -> auto-detect -> perspective warp -> OCR enhancement -> processed preview
- Camera validation page mirrors production lifecycle handling with `WidgetsBindingObserver`: release on inactive/paused/detached/hidden and recreate on resume
- Gallery path: host image picker -> EXIF orientation baked into a temporary JPEG -> `ImageCropView` -> normalized ROI -> native processing -> processed preview
- baking EXIF orientation before both display and processing ensures Gallery ROI coordinates refer to the same physical pixel layout, including mirrored EXIF orientations
- native errors are surfaced directly in the example for device validation
- CI builds the native validation entrypoint for Android arm64 so Dart FFI usage and Rust plugin packaging are both retained in the APK

## Remaining before v0.2 completion

1. CI/analyze/build cleanup for the native validation entrypoint.
2. Validate iOS and macOS native linkage on Apple toolchains.
3. Physical-device test of Camera auto-detect/warp and Gallery ROI processing, including a portrait EXIF-oriented Gallery JPEG.
4. Record validation evidence and close v0.2.

## Native build policy

The package keeps Flutter >=3.22 compatibility, so native packaging uses the legacy FFI-plugin platform build layout rather than requiring Flutter 3.38+ Native Assets build hooks. No native binary is committed to git.

`make install-hooks` installs the tracked pre-push guard. It runs Dart/Rust formatting and Rust validation locally before push.

## Documentation policy

Keep `docs/PROJECT_HANDOFF.md`, `docs/CODE_WALKTHROUGH.md`, and `docs/ROADMAP.md` synchronized for material architecture/native-processing changes.
