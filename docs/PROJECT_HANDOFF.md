# Project Handoff

Last updated: 2026-08-22

## Project

Repository: `dexter-cnx/dxtr_card_scan`

`dxtr_card_scan` is an OCR-engine-agnostic Flutter/Dart SDK for capturing cards/documents and preparing images for OCR. Flutter owns camera/UI/geometry. Rust owns deterministic preprocessing.

## Non-negotiable architecture decisions

1. Do not embed an OCR engine in the core package.
2. Do not let Rust own camera lifecycle or capture UI.
3. Do not crop captured images using raw Flutter preview coordinates.
4. Normalize preview/frame geometry before crossing the processing boundary.
5. Camera orientation/mirroring must be explicit.
6. Grayscale and hard thresholding are optional and should not be aggressive defaults.
7. Keep future `CardTemplate` and named OCR regions compatible with normalized coordinates.
8. Camera-specific controls may be demonstrated by the official `camera` plugin example, but core remains camera-plugin agnostic unless a stable adapter boundary is deliberately introduced.
9. File/image picking belongs to the host/example. Core accepts an image path and crop geometry but does not depend on an image picker.
10. Capture orientation policy must not lock the host application's OS orientation.
11. Camera and Gallery visuals inherit host theming. Package-specific visual tokens use `CardScanTheme`; standard Material controls still inherit host `ThemeData` / `ColorScheme`.
12. `Dxtr`/`dxtr` is reserved for the package/repository identity (`dxtr_card_scan`). Dart classes, typedefs, fields, variables, helpers, test names, and example UI labels use neutral domain names without a `Dxtr` prefix.
13. v0.2 card detection remains classical CV and deterministic. Do not add ML/AI detection unless classical CV proves insufficient with evidence.

## Current branch / PR

Branch: `agent/v0.2-quad-detection`
PR: pending

## v0.1 status

**Complete and merged. Physical-device validation passed on 2026-08-22.**

Validated on physical device:
- Home -> Camera / Gallery navigation
- Camera Back in portrait and both landscape orientations
- Back remains outside the scan frame
- Flash off / auto / on
- Torch toggle and restore behavior
- pinch-only zoom and zoom badge
- shutter/control theming
- settled portrait and landscape camera geometry
- configurable frame alignment/padding behavior
- portrait-only / landscape-only capture-policy behavior
- Gallery picker -> crop -> Use crop
- Gallery crop on real images
- custom `CardScanTheme` across Camera frame, Camera controls, and Gallery crop

## v0.2 PR1 status — Rust processor foundation

**Merged as PR #3.**

Implemented:
- Rust crate producing `cdylib`, `staticlib`, and `rlib`
- JPEG/PNG decode
- explicit clockwise quarter-turn orientation normalization
- normalized raw-image ROI quantized into integer half-open pixel bounds before rotation
- exact integer ROI rotation to avoid floating-point pixel-boundary drift
- crop
- optional grayscale
- optional max-dimension resize without upscaling
- JPEG/PNG encode
- stable C ABI with JSON options
- explicit result ownership/free contract
- panic containment at FFI boundary
- Rust format/clippy/test CI

## v0.2 PR2 status — quadrilateral detection

**In progress on `agent/v0.2-quad-detection`.**

Current detector stages:
1. grayscale working copy
2. deterministic 3x3 box blur
3. Sobel gradient magnitude
4. adaptive edge threshold from gradient mean + standard deviation
5. 8-connected edge components
6. convex hull extraction
7. four-corner quadrilateral approximation from hull extrema
8. candidate scoring

Candidate score components:
- area coverage
- rectangularity
- expected aspect-ratio similarity, accepting portrait rotation
- center/frame alignment
- edge strength

The Rust API currently exposes `detect_card_quad()` separately from `process_encoded()`. It returns normalized corners plus component scores and does not yet warp/crop using the detected quad. Keeping detection separate allows detector quality to be validated before perspective correction is introduced.

No new native CV dependency is introduced in PR2; the implementation uses the existing `image` crate plus Rust code.

## Capture frame geometry contract

`CaptureFrame` supports:
- `aspectRatio`
- `widthFactor`
- `maxHeightFactor`
- `fixedSize`
- `normalizedRect`
- `alignment`
- `alignmentPadding`

`alignment == null` keeps centered behavior. `alignmentPadding` defaults to `EdgeInsets.zero` and deflates the usable viewport before alignment and auto-size calculations.

## Capture orientation contract

`CardCaptureView` supports:

```dart
CaptureOrientationPolicy.any
CaptureOrientationPolicy.portraitOnly
CaptureOrientationPolicy.landscapeOnly
```

When orientation is rejected, preview remains visible, capture frame is hidden, capture is disabled, and optional host guidance may be shown. The package never forces host OS orientation.

## Camera vs Gallery frame constraints

Camera uses `CaptureFrame` with explicit ratio/size/alignment options. Gallery `ImageCropView` currently uses a normalized initial rectangle and freeform corner resizing. Gallery should remain capable of freeform cropping while adding an optional ratio/preset constraint later.

## Theme contract

Package-specific visuals use `CardScanTheme`, a Flutter `ThemeExtension`. Resolution order is explicit per-widget override, nearest `CardScanTheme`, then package defaults.

## Camera controls

Portrait:
- Back top-left
- Flash immediately to the right of Back
- Zoom top-center
- Torch top-right
- Shutter bottom-center
- pinch-only zoom

Landscape:
- `landscapeLeft`: shutter right
- `landscapeRight`: shutter left
- Back at the top of the same edge as shutter, outside the central scan frame
- opposite edge: Flash top / Zoom center / Torch bottom

## Example home + Gallery crop flow

Example Home has Camera and Gallery routes. `image_picker` exists only in the example. Gallery returns `ImageCropSelection(imagePath, NormalizedRect)`; Rust owns actual raster processing.

## Naming rule

`Dxtr`/`dxtr` remains reserved for package/repository identity. Public Dart domain types remain neutral.

## Remaining v0.2 order

After PR2 detector validation:
1. perspective warp using detected quad
2. detected-quad crop
3. optional OCR-oriented enhancement
4. optional resize/output integration
5. Dart FFI wrapper and native packaging after the Rust processing contract is stable

## Documentation policy

Update both `docs/CODE_WALKTHROUGH.md` and this handoff whenever a material PR changes architecture, public API, native processing, platform support, milestone status, or validation state.
