# Project Handoff

Last updated: 2026-08-22

## Project

Repository: `dexter-cnx/dxtr_card_scan`

`dxtr_card_scan` is an OCR-engine-agnostic Flutter/Dart SDK for card/document capture plus deterministic Rust preprocessing. Flutter owns capture UI/preview geometry. Rust owns deterministic raster processing.

## Architecture rules

1. Core does not embed an OCR engine.
2. Rust does not own camera lifecycle/UI.
3. Preview/frame geometry is normalized before processing.
4. Rotation/mirroring is explicit.
5. Default Camera and Gallery capture behavior belongs to the package; host apps configure the surfaces rather than reimplementing the pipeline.
6. Gallery/Camera labels are injectable so localization and wording stay host-controlled.
7. Host apps may replace the default Gallery picker through an escape-hatch callback without taking ownership of crop/process behavior.
8. Grayscale/OCR enhancement remains opt-in.
9. `Dxtr`/`dxtr` is reserved for package/repository identity; public Dart domain types remain neutral.
10. v0.2 detection remains deterministic classical CV.
11. `perspective_quad` is interpreted after orientation normalization and optional ROI crop.
12. Camera detection is constrained by the capture-frame ROI before auto-detect.
13. Perspective-warp canonicalization preserves source-top direction after long-edge normalization.
14. CPU-heavy image decode/orientation work and synchronous native FFI processing run off Flutter's UI isolate.
15. Desktop-selected files are read-only inputs; normalized/intermediate files are written to temporary storage.
16. File-backed staged images are preferred over eagerly copying multi-megabyte byte buffers; callers can request bytes when needed.

## Current status

`v0.2` is complete and closed.

PR #7 (`v0.2 PR5 — native processor validation flow`) passed CI and was squash-merged to `main` on 2026-08-22.

Merge SHA: `6b8b1bbeb4455e1d411926d8b7c56239f4a127e5`

Current branch: `feature/high-level-capture-pipeline`
Current PR: #9 — `High-level capture pipeline owned by package`

PR #9 is a pre-v0.3 API-ownership refactor. The goal is for Example code to define frame/UI configuration, processing options and result presentation only; Camera/Gallery mechanics remain package-owned.

## High-level capture API refactor

### Camera

`CardCaptureView` is now the high-level Camera surface and owns:
- camera discovery and lifecycle
- back camera selection
- Camera preview and `BoxFit.cover` geometry
- Back / flash / torch / pinch zoom / shutter controls
- orientation policy
- capture-frame rendering
- JPEG capture
- EXIF orientation normalization
- frame -> normalized source ROI mapping
- native auto-detect / perspective rectification
- optional post-rectification confirmation
- final enhancement/resize/encoding
- temporary intermediate files

Host configuration remains:
- `CaptureFrame`
- `CardScanProcessorOptions`
- `CaptureConfirmationMode`
- `CardCaptureControlsConfig`
- `CardCaptureLabels`
- theme/style overrides
- staged callbacks / final presentation

Camera result stages:
1. `onRawCaptured` — full camera image, not cropped
2. `onCropReady` — perspective-rectified card before final enhancement
3. `onCompleted` — `CardCaptureResult` containing `original`, `cropped`, and `processed`

### Gallery

`CardGalleryCaptureView` owns the default source-selection and processing path:
- Android/iOS: `image_picker`
- macOS: `file_selector`
- optional host `pickImagePath` override
- EXIF normalization
- `ImageCropView`
- ROI -> auto-detect -> perspective rectification
- optional confirmation
- final processing

`CardGalleryCropView` remains available when the host already owns a source path but still wants package-owned crop/process behavior.

All package-owned Gallery text is supplied through `GalleryCropLabels`.

### Image/result representation

`CardCaptureImage` uses a file path as its primary representation and exposes `readBytes()` for consumers that need bytes. This avoids forcing multi-megabyte copies between isolates or callbacks at every stage.

`CardCaptureResult` exposes:
- `original`
- `cropped`
- `processed`
- `sourceRoi`

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

Integrated example validated Camera and Gallery through the real Dart FFI/Rust processor path before the high-level API refactor.

## Final v0.2 validation evidence

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

Finish PR #9 CI/review and physical regression validation, then proceed to **v0.3 Quality analysis**:
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
