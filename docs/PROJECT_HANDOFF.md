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
10. Camera detection should be constrained by the capture-frame ROI before auto-detect so unrelated high-contrast background edges do not dominate quadrilateral selection.
11. Perspective-warp canonicalization must preserve the source top direction after long-edge normalization so cyclic quad start index cannot introduce a 180-degree output flip.

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

## v0.2 PR5 — integrated native flow

**In progress on `agent/v0.2-example-native-flow` as PR #7.**

Physical Android validation already proved:
- Rust native library loads on device
- Dart FFI calls Rust successfully
- Rust decode/process/encode returns bytes
- Flutter renders the processed bytes
- integrated Camera output no longer flips upside down after warp canonicalization was fixed on device

Physical iPhone 11 validation on 2026-08-22 proved:
- iOS example builds and launches on a physical device
- Camera capture succeeds
- the CocoaPods/Xcode script phase builds the Rust static library successfully for `iphoneos`
- the consuming Runner links the generated archive successfully
- Dart FFI invokes the Rust processor on-device
- processed output is returned and displayed successfully

The first physical Camera run exposed two integration issues rather than an FFI failure:
1. Camera/display orientation and warp canonicalization could produce an upside-down output.
2. Whole-frame auto detection could select strong background geometry and warp an otherwise straight card.

Current fix:
- default `flutter run` now opens `example/lib/integrated_card_scan_demo.dart`
- Camera uses the existing `CardCaptureView` / ID-1 frame
- zoom, flash off/auto/on, torch, orientation-aware shutter placement, Back, lifecycle handling, and theme support remain available
- captured JPEG is decoded and `bakeOrientation()` is applied before processing
- the resolved capture frame is mapped through `PreviewGeometry` into normalized source-image ROI coordinates
- Rust auto-detect/warp runs only inside that frame-derived ROI
- warp canonicalization now compares the two long-edge midpoints and chooses the source-top long edge as output top, removing 180-degree cyclic-start ambiguity
- Rust regression coverage includes a quad whose cyclic order starts on the bottom edge
- OCR enhancement and processed preview follow the warp
- Gallery also normalizes EXIF orientation before crop/processing so UI ROI and raw pixels share one coordinate system
- iOS/macOS podspec script phases declare their generated Rust archive as an Xcode output so the consuming target does not try to `-force_load` a file before it is built
- generated iOS example signing uses Development Team `ZTM9BCJPY9`

## Remaining before v0.2 completion

1. Finish Android physical Camera validation: frame ROI/warp correctness plus zoom/flash/torch regression.
2. Re-test Gallery ROI processing including portrait EXIF-oriented images.
3. Validate macOS native linkage on an Apple toolchain.
4. Record final validation evidence and close v0.2.

## Native build policy

The package keeps Flutter >=3.22 compatibility, so native packaging uses the legacy FFI-plugin platform build layout rather than requiring Flutter 3.38+ Native Assets build hooks. No native binary is committed to git.

Generated native build state such as `android/.cxx/` and `rust/target/` is ignored. `rust/Cargo.lock` should remain committed because Rust is an embedded native implementation and reproducible dependency resolution is desirable.

`make install-hooks` installs the tracked pre-push guard. It runs Dart/Rust formatting and Rust validation locally before push.

## Documentation policy

Keep `docs/PROJECT_HANDOFF.md`, `docs/CODE_WALKTHROUGH.md`, and `docs/ROADMAP.md` synchronized for material architecture/native-processing changes.
