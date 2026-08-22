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

`alignment == null` keeps the original centered behavior. `alignmentPadding` defaults to `EdgeInsets.zero` and deflates the usable viewport before alignment and auto-size calculations. This supports top/bottom/side placement with configurable pitch from the edge.

The example still uses centered `CaptureFrame.id1(widthFactor: .88, maxHeightFactor: .82)` unless a host opts into another alignment.

### Capture orientation contract

`CardCaptureView` supports:

```dart
CaptureOrientationPolicy.any
CaptureOrientationPolicy.portraitOnly
CaptureOrientationPolicy.landscapeOnly
```

When orientation is rejected:
- preview remains visible;
- capture frame is hidden;
- controller capture is disabled;
- optional `orientationMismatchBuilder` may show rotate-device guidance.

The package never forces host OS orientation.

### Camera vs Gallery frame constraints

Camera uses `CaptureFrame` with explicit ratio/size/alignment options. Gallery `ImageCropView` currently uses a normalized initial rectangle and freeform corner resizing. Gallery should remain capable of freeform cropping while adding an optional ratio/preset constraint later so a host can request ID-1 or another document ratio.

### Theme contract

Package-specific visuals use `CardScanTheme`, a Flutter `ThemeExtension`:

```dart
ThemeData(
  extensions: const [
    CardScanTheme(
      captureFrameStyle: CaptureFrameStyle(
        borderColor: Colors.amber,
        borderWidth: 3,
      ),
      imageCropStyle: ImageCropStyle(
        borderColor: Colors.cyan,
        handleColor: Colors.orange,
      ),
      cameraControlsStyle: CameraControlsStyle(
        shutterSize: 92,
        activeControlBackgroundColor: Colors.amber,
      ),
    ),
  ],
)
```

Resolution order for Camera frame and Gallery crop:
1. explicit per-widget override;
2. nearest `CardScanTheme` in `ThemeData.extensions`;
3. package defaults.

`CameraControlsStyle` covers shutter size/shape/colors/border, normal and active Back/Flash/Torch colors, and Zoom badge colors. Nullable colors fall back to host Material `ColorScheme`.

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

Capabilities:
- Flash off / auto / on
- independent Torch toggle restoring prior still-photo flash mode
- device min/max zoom queried at initialization
- pinch-only zoom with current-scale badge

## Example home + Gallery crop flow

Example Home has:
1. `Camera` -> full-screen secondary camera route.
2. `Gallery` -> example-owned `image_picker`, then package `ImageCropView(imagePath: ...)`.

`image_picker` exists only in `example/pubspec.yaml`.

Gallery crop:
- accepts host-provided image path;
- loads source dimensions;
- uses `BoxFit.contain` source-image geometry;
- crop rectangle moves/resizes from four corners;
- returns `ImageCropSelection(imagePath, NormalizedRect)`;
- actual raster crop/encode remains for v0.2 Rust processing.

## Naming cleanup completed

Public theme API is now `CardScanTheme` in `lib/src/theme/card_scan_theme.dart`. The old `DxtrCardScanTheme` type/file and prefixed test file were removed rather than retained as deprecated aliases. `lib/dxtr_card_scan.dart` remains prefixed because it is the package barrel/import identity.

## Automated validation required

Latest material changes must pass:
- package analyze
- package unit tests, including alignment/padding, orientation policy, and theme resolution/interpolation
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
7. top/bottom frame alignment with non-zero padding when configured.
8. `portraitOnly` / `landscapeOnly` mismatch behavior when configured.
9. a custom `CardScanTheme` applied across Camera frame, Camera controls, and Gallery crop.

Do not begin v0.2 until this targeted device pass is complete.

## Next milestone: v0.2 Rust processor

Planned order:
1. orientation normalization
2. expected-frame or manual-crop ROI
3. grayscale working copy
4. blur/edge detection
5. contours and quadrilateral approximation
6. candidate scoring
7. perspective warp
8. crop
9. optional OCR-oriented enhancement
10. optional resize
11. output encoding

Do not introduce ML/AI detection in v0.2 unless classical CV proves insufficient with evidence.

## Documentation policy

Update both `docs/CODE_WALKTHROUGH.md` and this handoff whenever a material PR changes architecture, public API, native processing, platform support, milestone status, or validation state.
