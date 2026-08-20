# Project Handoff

Last updated: 2026-08-20

## Project

Repository: `dexter-cnx/dxtr_card_scan`

Dxtr Card Scan is an OCR-engine-agnostic Flutter/Dart SDK for capturing cards/documents and preparing images for OCR. Flutter owns camera/UI/geometry. Rust owns deterministic preprocessing.

## Non-negotiable architecture decisions

1. Do not embed an OCR engine in the core package.
2. Do not let Rust own camera lifecycle or capture UI.
3. Do not crop captured images using raw Flutter preview coordinates.
4. Normalize preview/frame geometry before crossing the processing boundary.
5. Camera orientation/mirroring must be explicit; do not assume the captured file is already orientation-normalized.
6. Grayscale and hard thresholding are optional and should not be aggressive defaults.
7. Keep future `CardTemplate` and named OCR regions compatible with the normalized-coordinate model.
8. Camera-specific controls may be demonstrated by the official `camera` plugin example, but the core package remains camera-plugin agnostic unless a stable adapter boundary is deliberately introduced.
9. File/image picking belongs to the host/example. The package may accept an image path and expose crop geometry, but must not depend on an image picker.
10. Capture orientation policy must not lock the host application's OS orientation. The package only allows/disallows capture for the current viewport orientation; the host decides whether to call `SystemChrome.setPreferredOrientations`.

## Current branch / PR

Branch: `agent/v0.1-capture-foundation`
PR: #2

## v0.1 Capture foundation

Confirmed on physical device:
- back camera opens
- portrait ID-1 frame is centered and proportionally reasonable
- settled portrait preview is not squeezed/stretched
- settled landscape preview/frame geometry is correct
- short transient distortion can appear during rotation, but settled preview is correct

Implemented foundation:
- Flutter package scaffold
- normalized geometry and preview-to-image mapping
- explicit captured-image rotation/mirroring contract
- configurable ID-1 frame with landscape height clamping
- camera-plugin-agnostic capture view/controller
- real-camera reference example using Flutter `camera`
- CI analyze/test/example/Android-build gates

### Camera frame geometry contract

`CaptureFrame` supports:
- `aspectRatio`
- `widthFactor`
- `maxHeightFactor`
- `fixedSize`
- `normalizedRect`
- `alignment`
- `alignmentPadding`

`alignment == null` preserves the original centered behavior. `alignmentPadding` defaults to `EdgeInsets.zero` and defines an inset viewport before alignment is resolved. Examples:

```dart
const CaptureFrame.id1(
  alignment: Alignment.topCenter,
  alignmentPadding: EdgeInsets.only(top: 32),
)
```

```dart
const CaptureFrame.id1(
  alignment: Alignment.bottomCenter,
  alignmentPadding: EdgeInsets.only(bottom: 48),
)
```

For auto-sized frames, width/height are calculated from the viewport after `alignmentPadding` is removed, which prevents large insets from pushing the frame outside the usable area. When `normalizedRect` is supplied, it already defines both size and position, so `alignment` and `alignmentPadding` are ignored.

The example Camera still uses `CaptureFrame.id1(widthFactor: .88, maxHeightFactor: .82)` and therefore remains centered until a host opts into another alignment.

### Capture orientation contract

`CardCaptureView` now supports:

```dart
orientationPolicy: CaptureOrientationPolicy.any
orientationPolicy: CaptureOrientationPolicy.portraitOnly
orientationPolicy: CaptureOrientationPolicy.landscapeOnly
```

Default is `any` for backward compatibility.

When the viewport orientation does not satisfy the policy:
- camera preview remains visible;
- capture frame is hidden;
- `CardCaptureController` is disabled and rejects capture;
- optional `orientationMismatchBuilder` may render host-specific rotate-device guidance.

The package does not force OS orientation. A host that wants a physically locked portrait-only/landscape-only screen may additionally lock orientation in the app layer.

### Camera vs Gallery frame constraints

Camera and Gallery do not yet expose identical constraints:
- Camera uses `CaptureFrame` with explicit ratio/size/alignment options.
- Gallery `ImageCropView` currently uses a normalized initial rectangle and freeform corner resizing.
- Gallery should remain capable of freeform cropping, but Roadmap now tracks an optional ratio/preset constraint so hosts can request the same ID-1 or custom ratio used by Camera.

## v0.1.1 Camera controls

Portrait:
- Back top-left
- Flash immediately to the right of Back
- zoom scale top-center
- Torch top-right
- shutter bottom-center
- pinch-only zoom

Landscape:
- camera remains full-screen
- `landscapeLeft`: shutter right
- `landscapeRight`: shutter left
- Back at the top of the same edge as shutter, outside the central scan frame
- opposite edge: Flash top / zoom center / Torch bottom

Camera capabilities:
- Flash off / auto / on
- independent Torch toggle restoring previous still-photo flash mode
- device min/max zoom queried at initialization
- pinch-only zoom with current-scale badge

## v0.1.2 Example home + Gallery crop flow

Example Home has:
1. `Camera` -> full-screen secondary camera route.
2. `Gallery` -> example-owned `image_picker`, then package `ImageCropView(imagePath: ...)`.

Picker boundary:
- `image_picker` exists only in `example/pubspec.yaml`.
- core package remains picker-agnostic.

Package Gallery crop API:
- accepts host-provided image path;
- loads source dimensions;
- uses `BoxFit.contain` source-image geometry;
- crop rectangle can move and resize from four corners;
- output is `ImageCropSelection(imagePath, NormalizedRect)`;
- actual raster crop/encode remains for v0.2 Rust processing.

## Automated validation required

Latest material changes must pass:
- package analyze
- package unit tests, including alignment/padding and orientation policy
- example dependencies/analyze
- Android/iOS host scaffolding generation
- Android debug APK build

## Next physical-device retest

Validate:
1. Home -> Camera / Gallery navigation.
2. Camera Back in portrait and both landscape orientations.
3. Camera Back remains outside scan frame.
4. Flash/Torch/pinch zoom behavior.
5. Gallery picker -> crop -> Use crop.
6. Gallery crop on portrait and landscape source images.
7. If exercising new frame APIs, verify top/bottom alignment with non-zero padding.
8. If exercising `portraitOnly` or `landscapeOnly`, verify frame disappears and capture is disabled in the disallowed orientation, while preview remains visible.

Do not begin v0.2 until this targeted device pass is complete.

## Next milestone: v0.2 Rust processor

Planned processing order:
1. orientation normalization
2. expected-frame or manual-crop ROI (+ configurable margin when detection is used)
3. grayscale working copy for detection
4. blur/edge detection
5. contours and quadrilateral approximation
6. candidate scoring
7. perspective warp
8. crop
9. optional OCR-oriented enhancement
10. optional resize
11. output encoding

Do not introduce ML/AI detection in v0.2 unless classical CV proves insufficient with evidence.

## Future milestones

- v0.3 quality analysis: blur, exposure, coverage, confidence
- v0.4 live detection + optional auto-capture
- v0.5 `CardTemplate` + named OCR regions
- v1.0 stable API, Android/iOS/macOS, benchmarks and full example

## Documentation policy

Update both `docs/CODE_WALKTHROUGH.md` and this handoff whenever a material PR changes architecture, public API, native processing, platform support, milestone status, or validation state.
