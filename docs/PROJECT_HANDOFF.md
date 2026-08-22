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
10. Camera detection is constrained by the capture-frame ROI before auto-detect.
11. Perspective-warp canonicalization preserves source-top direction after long-edge normalization.
12. CPU-heavy image decode/orientation work and synchronous native FFI processing run off Flutter's UI isolate in the integrated example.
13. Desktop-selected files are read-only inputs; normalized/intermediate files are written to temporary storage.

## Current status

`v0.2` is complete and closed.

PR #7 (`v0.2 PR5 — native processor validation flow`) passed CI and was squash-merged to `main` on 2026-08-22.

Merge SHA: `6b8b1bbeb4455e1d411926d8b7c56239f4a127e5`

## Completed

### v0.1 capture foundation

Camera/Gallery navigation, portrait/landscape controls, flash, torch, pinch zoom, configurable capture-frame alignment/padding, orientation policies, Gallery crop, and `CardScanTheme` passed physical-device validation.

### v0.2 PR1 — Rust processor foundation

JPEG/PNG decode, orientation normalization, pixel-stable ROI crop, optional grayscale/resize, encoding, stable C ABI, result ownership/free contract, and panic containment.

### v0.2 PR2 — quadrilateral detection

Deterministic classical-CV detection: grayscale/blur/Sobel/adaptive threshold, flat-image rejection, connected components, convex hull, distinct-corner quad approximation, scoring, and regression coverage.

### v0.2 PR3 — perspective warp / OCR enhancement

Deterministic projective warp, bilinear sampling, cyclic-quad handling, source-top-preserving long-edge orientation, bounded output size, auto-detect/manual quad integration, OCR enhancement, and regression coverage.

### v0.2 PR4 — Dart FFI + native packaging

- public `CardScanProcessor`
- `processBytes()` / `processFile()`
- native status/error mapping via `CardScanProcessorException`
- `CardScanProcessorOptions`, `ProcessorQuad`, `ProcessorPoint`, `ProcessorOutputFormat`
- Android Gradle/CMake -> Cargo packaging
- iOS/macOS CocoaPods/Xcode -> Cargo packaging
- Darwin generated static archive consumed by the plugin Pod target
- Flutter >=3.22 compatibility retained

### v0.2 PR5 — integrated native flow

Integrated example now validates Camera and Gallery through the real Dart FFI/Rust processor path.

Camera flow:
1. capture JPEG
2. bake EXIF orientation on a worker isolate
3. resolve the visible capture frame to normalized source ROI
4. auto-detect inside that ROI
5. perspective warp
6. optional OCR enhancement
7. render processed bytes

Gallery flow:
1. Android/iOS use `image_picker`; macOS uses `file_selector`
2. decode + bake EXIF orientation on a worker isolate
3. write normalized image to temporary storage
4. crop using `ImageCropView`
5. block accidental system-back navigation while cropping
6. run ROI -> auto-detect -> perspective warp -> encode on a worker isolate
7. preserve color by default

## Final validation evidence

Android physical validation:
- Camera capture/process/render passed
- output orientation fixed
- frame ROI / warp behavior acceptable
- zoom / flash / torch regressions passed
- Gallery responsive loading passed
- crop/back protection passed
- Gallery perspective correction passed
- color output passed

Physical iPhone 11 validation:
- app build/launch passed
- Camera capture passed
- Rust static archive build/link passed
- Dart FFI -> Rust processing passed
- processed output rendering passed
- Gallery after isolate/refactor passed

macOS validation:
- generated macOS host build/launch passed
- Rust archive build/link through plugin Pod target passed
- native file picker can browse folders and select images
- sandbox-safe temporary normalization passed
- Gallery crop / FFI / Rust processing / perspective correction / preview passed

CI run `32569564457` passed Flutter analyze/tests, Android native APK build, Rust format, Clippy, and Rust tests. All PR review threads were resolved before merge.

## Important fixes learned during validation

1. Camera JPEG/display orientation must be normalized before ROI mapping.
2. Cyclic quad start order must not be allowed to introduce a 180-degree warp flip.
3. Camera auto-detect should run inside the visible capture-frame ROI, not the full image.
4. CPU-heavy image preparation and synchronous FFI should not run on Flutter's UI isolate.
5. Darwin `-force_load` belongs to the plugin Pod target that owns the Rust build phase, not the Runner target.
6. macOS sandbox-selected files must not be used as output locations for normalized/intermediate files.
7. Desktop Gallery uses a desktop-native picker rather than mobile-oriented `image_picker`.

## Next milestone

Proceed to **v0.3 Quality analysis**:
- blur score
- exposure quality
- card coverage
- detection confidence

Keep quality analysis as measurements first; do not couple it to live auto-capture until the metrics are stable.

## Native build policy

The package keeps Flutter >=3.22 compatibility, so native packaging uses the legacy FFI-plugin platform build layout rather than requiring Flutter 3.38+ Native Assets build hooks. No native binary is committed to git.

Generated native build state such as `android/.cxx/`, generated example platform hosts, and `rust/target/` is ignored. `rust/Cargo.lock` remains committed for reproducible embedded native builds.

## Documentation policy

Keep `docs/PROJECT_HANDOFF.md`, `docs/CODE_WALKTHROUGH.md`, and `docs/ROADMAP.md` synchronized for material architecture/native-processing changes.
