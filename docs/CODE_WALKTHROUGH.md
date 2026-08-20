# Code Walkthrough

This document tracks the implementation as the package evolves. Update it with every material milestone.

## 0.1 Capture foundation

### `lib/dxtr_card_scan.dart`
The public barrel. Only intended public API is exported from here, including `CaptureOrientationPolicy`, `DxtrCardScanTheme`, `CaptureFrameStyle`, and `ImageCropStyle`.

### `src/geometry/normalized_rect.dart`
`NormalizedRect` is the stable geometry primitive. It stores left/top/right/bottom in `[0,1]` space and converts to or from pixel `Rect` values for a known image size.

### `src/geometry/captured_image_transform.dart`
`CapturedImageTransform` maps displayed normalized geometry back to raw captured-image coordinates, including rotation and horizontal mirroring.

### `src/geometry/preview_geometry.dart`
`PreviewGeometry` maps a frame over a `BoxFit.cover` preview into source-image geometry, then applies `CapturedImageTransform` to reach raw captured-image coordinates.

### `src/frame/capture_frame.dart`
`CaptureFrame` supports ID-1, arbitrary aspect ratio + width factor, fixed size, or normalized rectangle. Auto-sized frames use `maxHeightFactor` so landscape height is clamped while preserving aspect ratio.

Frame placement is configurable:
- `alignment == null` -> historical centered behavior.
- any Flutter `Alignment` may be supplied.
- `alignmentPadding` defaults to `EdgeInsets.zero` and deflates the viewport before alignment is resolved.

Auto-size calculations use the post-padding viewport size. `normalizedRect` bypasses alignment because it already specifies position and size directly.

### `src/capture/capture_orientation_policy.dart`
`CaptureOrientationPolicy` has `any`, `portraitOnly`, and `landscapeOnly`. It is a viewport-level policy and never calls `SystemChrome`.

### `src/capture/card_capture_view.dart`
`CardCaptureView` composes a host-provided preview and customizable frame without importing a camera plugin.

The widget applies `orientationPolicy` using its actual layout size. In a rejected orientation, preview remains visible, frame is hidden, and controller capture is disabled. `orientationMismatchBuilder` can provide host-specific guidance.

`frameStyle` is now optional. Resolution order is:
1. explicit `CardCaptureView.frameStyle`;
2. `DxtrCardScanTheme.of(context).captureFrameStyle`;
3. default `CaptureFrameStyle` supplied by the theme extension fallback.

### `src/capture/card_capture_controller.dart`
`CardCaptureController` owns no camera hardware. `setCaptureEnabled(bool)` lets `CardCaptureView` reject captures while orientation policy is unsatisfied without detaching the delegate.

## Theme system

### `src/theme/dxtr_card_scan_theme.dart`
`DxtrCardScanTheme` is a Flutter `ThemeExtension`. It groups the package-specific visual tokens shared by Camera and Gallery:
- `captureFrameStyle`
- `imageCropStyle`

It supports `copyWith`, interpolation through `lerp`, and `DxtrCardScanTheme.of(context)` with a default fallback. Hosts can install it once in `ThemeData.extensions` and both capture surfaces inherit it.

Example:

```dart
ThemeData(
  extensions: const [
    DxtrCardScanTheme(
      captureFrameStyle: CaptureFrameStyle(
        borderColor: Colors.amber,
        borderWidth: 3,
      ),
      imageCropStyle: ImageCropStyle(
        borderColor: Colors.cyan,
        handleColor: Colors.orange,
      ),
    ),
  ],
)
```

This package theme is intentionally narrow. AppBars, buttons, icon buttons, text, and other standard Material widgets continue to inherit the host `ThemeData` / `ColorScheme` rather than duplicating Material theming.

### `src/frame/capture_frame_style.dart`
`CaptureFrameStyle` controls Camera guide visuals: border color/width, corner radius, and outside overlay. It supports `copyWith` and interpolation for theme animation.

### `src/crop/image_crop_style.dart`
`ImageCropStyle` controls Gallery crop visuals: outside overlay, border color/width, handle fill/border, visible handle size, and gesture hit size. Keeping hit size separate from visible size allows touch ergonomics without forcing large visual handles.

## 0.1.2 Manual image crop API

### `src/crop/image_crop_selection.dart`
`ImageCropSelection` is the Gallery equivalent of the camera ROI boundary. It contains the host-provided image path plus a source-relative `NormalizedRect`.

### `src/crop/image_crop_view.dart`
`ImageCropView` accepts a local image path from the host and resolves intrinsic image dimensions with `FileImage`. `BoxFit.contain` geometry ensures letterbox regions never become part of the crop coordinate system.

The current Gallery crop is freeform: users can move the rectangle and resize from four corners. Gallery does not yet consume `CaptureFrame` constraints; Roadmap tracks optional ratio/preset constraints while retaining freeform as default.

`style` is optional and follows the same precedence as Camera: per-widget style first, then `DxtrCardScanTheme.imageCropStyle`, then package defaults.

No pixels are rewritten yet. v0.2 will take `imagePath + normalizedRect` and perform actual deterministic crop/preprocessing in Rust.

## Example application

### Home routing

`example/lib/main.dart` starts with `ExampleHomePage`:
- `Camera` -> pushes `CameraCapturePage`.
- `Gallery` -> example-owned `ImagePicker`, then `GalleryCropPage` with only the selected path.

`image_picker` is an example dependency only.

### Gallery crop page

`GalleryCropPage` is a conventional secondary editor screen with AppBar Back, system Back support, and `Use crop` returning the latest `ImageCropSelection`. Standard controls inherit the example app's Material theme; `ImageCropView` additionally inherits `DxtrCardScanTheme` when installed.

### Camera preview and controls

`_CoverCameraPreview` uses orientation-aware displayed aspect ratio plus `BoxFit.cover`. Settled portrait/landscape preview geometry has already been validated on device.

Zoom is pinch-only; `_ZoomBadge` shows current scale. Still-photo flash selection is stored independently from temporary torch state. Standard control widgets inherit Material component themes; the scan guide inherits `DxtrCardScanTheme.captureFrameStyle`.

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
- theme extension resolution/interpolation tests
- example dependency resolution/analyze
- Android/iOS host generation
- Android debug APK build

## Manual validation boundary

The next device pass should cover Home -> Camera -> Back, Home -> Gallery -> picker -> crop -> Use crop, existing flash/torch/pinch zoom, landscape control placement, and one custom `DxtrCardScanTheme` applied across Camera and Gallery.

## Next walkthrough section

v0.2 should document the Rust crate layout, Dart/FFI DTO boundary, image-buffer ownership, native error mapping, camera ROI vs manual Gallery ROI, and each preprocessing stage.
