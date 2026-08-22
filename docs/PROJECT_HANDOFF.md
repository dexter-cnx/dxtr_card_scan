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

## v0.1 status

**Implementation complete. Automated validation passed. Physical-device validation passed on 2026-08-22.**

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

Latest pre-validation code CI passed in run `32558024492`. Final documentation-only sync must also remain green before merge.

## Capture frame geometry contract

`CaptureFrame` supports:
- `aspectRatio`
- `widthFactor`
- `maxHeightFactor`
- `fixedSize`
- `normalizedRect`
- `alignment`
- `alignmentPadding`

`alignment == null` keeps centered behavior. `alignmentPadding` defaults to `EdgeInsets.zero` and deflates the usable viewport before alignment and auto-size calculations. This supports top/bottom/side placement with configurable pitch from the edge.

The example uses centered `CaptureFrame.id1(widthFactor: .88, maxHeightFactor: .82)` unless a host opts into another alignment.

## Capture orientation contract

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

## Camera vs Gallery frame constraints

Camera uses `CaptureFrame` with explicit ratio/size/alignment options. Gallery `ImageCropView` currently uses a normalized initial rectangle and freeform corner resizing. Gallery should remain capable of freeform cropping while adding an optional ratio/preset constraint later so a host can request ID-1 or another document ratio.

This Gallery ratio/preset item remains intentionally deferred and does not block v0.1 completion.

## Theme contract

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

Public theme API is `CardScanTheme` in `lib/src/theme/card_scan_theme.dart`. The old `DxtrCardScanTheme` type/file and prefixed test file were removed rather than retained as deprecated aliases. `lib/dxtr_card_scan.dart` remains prefixed because it is the package barrel/import identity.

## v0.1 completion / merge gate

Completed:
- package analyze/tests
- alignment/padding tests
- orientation-policy tests
- theme resolution/interpolation tests
- example analyze
- Android/iOS host scaffold generation
- Android debug APK build
- physical-device Camera/Gallery validation

Next action after final documentation CI is green:
1. mark PR #2 Ready for review;
2. merge PR #2;
3. remove `agent/v0.1-capture-foundation` if no longer needed;
4. start v0.2 on a new branch from `main`.

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
