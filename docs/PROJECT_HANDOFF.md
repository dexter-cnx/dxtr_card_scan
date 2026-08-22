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
12. CPU-heavy image decode/orientation work and synchronous native FFI processing should run off Flutter's UI isolate in the example integration flow.

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

Physical Android validation on 2026-08-22 proved:
- Rust native library loads on device
- Dart FFI calls Rust successfully
- Rust decode/process/encode returns bytes
- Flutter renders the processed bytes
- integrated Camera output no longer flips upside down after warp canonicalization was fixed on device
- Camera frame ROI / warp behavior is acceptable on device
- zoom / flash / torch / Camera controls regressions did not reproduce
- updated Gallery shows a responsive loading state after picking an image
- crop interaction remains stable with system/predictive-back blocked on the crop route
- Gallery `Scan selection` performs perspective correction successfully
- Gallery processed preview remains color instead of looking like an OCR-enhanced grayscale crop

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

Both Camera issues are fixed and passed Android physical re-test.

Gallery physical testing then exposed three integration/UX issues:
1. decode + EXIF bake on the UI isolate made the screen appear frozen after picking an image.
2. Android system/predictive-back gestures could interfere with crop interaction near screen edges.
3. Gallery processing only did ROI crop + OCR enhancement, so the output looked like a grayscale crop rather than a rectified scan.

The updated Gallery flow now passes Android physical re-test for all four target behaviors: visible responsive loading, stable crop/back protection, perspective correction, and color output.

Current Gallery implementation:
- `example/lib/background_scan_tasks.dart` runs image decode/EXIF bake and synchronous FFI/Rust processing through `Isolate.run()`
- the integrated example is split into dedicated Camera / Gallery / processed-preview files
- Gallery shows a blocking progress overlay and status text while preparing or processing
- Gallery crop route uses `PopScope` to block device/system back gestures; leaving the page is explicit through its Close button
- Gallery `Scan selection` runs `ROI -> auto-detect -> perspective warp -> encode`
- Gallery preview keeps color by default (`enhanceForOcr: false`); OCR enhancement remains opt-in processor behavior
- the user should keep the whole card inside the crop so detector geometry remains available within the selected ROI

Additional native packaging fixes:
- iOS/macOS podspec script phases declare their generated Rust archive as an Xcode output so the consuming target does not try to `-force_load` a file before it is built
- generated iOS example signing uses Development Team `ZTM9BCJPY9`

## Remaining before v0.2 completion

1. Re-test Gallery/native flow on iPhone after the isolate/refactor change.
2. Validate macOS native linkage and Gallery processing on an Apple toolchain.
3. Confirm PR #7 CI/review state is clean.
4. Record final validation evidence, merge PR #7, and close v0.2.

## Native build policy

The package keeps Flutter >=3.22 compatibility, so native packaging uses the legacy FFI-plugin platform build layout rather than requiring Flutter 3.38+ Native Assets build hooks. No native binary is committed to git.

Generated native build state such as `android/.cxx/` and `rust/target/` is ignored. `rust/Cargo.lock` should remain committed because Rust is an embedded native implementation and reproducible dependency resolution is desirable.

`make install-hooks` installs the tracked pre-push guard. It runs Dart/Rust formatting and Rust validation locally before push.

## Documentation policy

Keep `docs/PROJECT_HANDOFF.md`, `docs/CODE_WALKTHROUGH.md`, and `docs/ROADMAP.md` synchronized for material architecture/native-processing changes.
