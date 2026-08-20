# Code Walkthrough

This document tracks the implementation as the package evolves. Update it with every material milestone.

## 0.1 Capture foundation

### `lib/dxtr_card_scan.dart`
The public barrel. Only intended public API is exported from here, including `CaptureOrientationPolicy`.

### `src/geometry/normalized_rect.dart`
`NormalizedRect` is the stable geometry primitive. It stores left/top/right/bottom in `[0,1]` space and converts to or from pixel `Rect` values for a known image size.

### `src/geometry/captured_image_transform.dart`
`CapturedImageTransform` maps displayed normalized geometry back to raw captured-image coordinates, including rotation and horizontal mirroring.

### `src/geometry/preview_geometry.dart`
`PreviewGeometry` maps a frame over a `BoxFit.cover` preview into source-image geometry, then applies `CapturedImageTransform` to reach raw captured-image coordinates.

### `src/frame/capture_frame.dart`
`CaptureFrame` supports ID-1, arbitrary aspect ratio + width factor, fixed size, or normalized rectangle. Auto-sized frames use `maxHeightFactor` so landscape height is clamped while preserving aspect ratio.

Frame placement is also configurable:
- `alignment == null` -> historical centered behavior.
- any Flutter `Alignment` value may be supplied, including `topCenter`, `bottomCenter`, corners, or a custom fractional alignment.
- `alignmentPadding` defaults to `EdgeInsets.zero` and deflates the viewport before alignment is resolved.

For example:

```dart
const CaptureFrame.id1(
  alignment: Alignment.topCenter,
  alignmentPadding: EdgeInsets.only(top: 32),
)
```

Auto-size calculations use the post-padding viewport size. This means padding is part of the geometry constraint, not merely a visual translation. `normalizedRect` bypasses alignment because it already specifies position and size directly.

### `src/capture/capture_orientation_policy.dart`
`CaptureOrientationPolicy` has three values:
- `any`
- `portraitOnly`
- `landscapeOnly`

`allows(Orientation)` is intentionally a viewport-level decision. It does not call `SystemChrome` and does not force the host application's physical orientation.

### `src/capture/card_capture_view.dart`
`CardCaptureView` composes a host-provided preview and customizable frame without importing a specific camera plugin.

The widget determines portrait/landscape from its actual layout size and applies `orientationPolicy`:
- allowed -> preview + frame render normally and capture remains enabled;
- disallowed -> preview remains visible, frame is omitted, controller capture is disabled;
- optional `orientationMismatchBuilder` can overlay a rotate-device prompt or any host-specific UI.

This separation lets a host choose between a soft policy (show preview but disallow capture) and a hard app-level orientation lock.

### `src/capture/card_capture_controller.dart`
`CardCaptureController` still owns no camera hardware. It now also has `setCaptureEnabled(bool)` so `CardCaptureView` can reject captures while orientation policy is unsatisfied without detaching the camera delegate.

## 0.1.2 Manual image crop API

### `src/crop/image_crop_selection.dart`
`ImageCropSelection` is the Gallery equivalent of the camera ROI boundary. It contains the host-provided image path plus a source-relative `NormalizedRect`.

### `src/crop/image_crop_view.dart`
`ImageCropView` accepts a local image path from the host and resolves intrinsic image dimensions with `FileImage`. `BoxFit.contain` geometry ensures letterbox regions never become part of the crop coordinate system.

The current Gallery crop is freeform: users can move the rectangle and resize from four corners. Gallery does not yet consume `CaptureFrame` constraints; Roadmap tracks optional ratio/preset constraints so hosts can request ID-1 or another ratio while retaining freeform as the default.

No pixels are rewritten yet. v0.2 will take `imagePath + normalizedRect` and perform actual deterministic crop/preprocessing in Rust.

## Example application

### Home routing

`example/lib/main.dart` starts with `ExampleHomePage`:
- `Camera` -> pushes `CameraCapturePage`.
- `Gallery` -> example-owned `ImagePicker`, then `GalleryCropPage` with only the selected path.

`image_picker` is an example dependency only.

### Gallery crop page

`GalleryCropPage` is a conventional secondary editor screen with AppBar Back, system Back support, and `Use crop` returning the latest `ImageCropSelection`.

### Camera preview and controls

`_CoverCameraPreview` uses orientation-aware displayed aspect ratio plus `BoxFit.cover`. Settled portrait/landscape preview geometry has already been validated on device.

Zoom is pinch-only; `_ZoomBadge` shows current scale. Still-photo flash selection is stored independently from temporary torch state.

Portrait controls:
- Back top-left
- Flash immediately after Back
- Zoom top-center
- Torch top-right
- Shutter bottom-center

Landscape controls use `camera.value.deviceOrientation`:
- `landscapeLeft` -> shutter right
- `landscapeRight` -> shutter left
- Back at the top of the shutter edge
- opposite edge -> Flash top / Zoom center / Torch bottom

## Generated platform hosts

`tool/bootstrap_example_platforms.sh` generates Android/iOS host scaffolding and injects camera/photo-library usage descriptions. Generated platform folders remain uncommitted.

Useful commands:

```sh
make example-platforms
make example-build-android
```

## Automated validation

CI gates:
- package analyze
- package unit tests
- frame alignment/padding tests
- orientation-policy tests
- example dependency resolution/analyze
- Android/iOS host generation
- Android debug APK build

## Manual validation boundary

The next device pass should cover Home -> Camera -> Back, Home -> Gallery -> picker -> crop -> Use crop, existing flash/torch/pinch zoom, and landscape control placement. New frame placement/orientation APIs should also be sanity-checked when exercised by a host configuration.

## Next walkthrough section

v0.2 should document the Rust crate layout, Dart/FFI DTO boundary, image-buffer ownership, native error mapping, camera ROI vs manual Gallery ROI, and each preprocessing stage.
