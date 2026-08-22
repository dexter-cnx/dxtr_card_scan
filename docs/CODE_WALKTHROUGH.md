# Code Walkthrough

This document tracks the implementation as the package evolves. Update it with every material milestone.

## 0.1 Capture foundation

### `lib/dxtr_card_scan.dart`
The public barrel. `dxtr_card_scan` is the package/library name; public Dart types intentionally avoid a package-name prefix. Exported APIs include `CaptureOrientationPolicy`, `CardScanTheme`, `CaptureFrameStyle`, `ImageCropStyle`, and `CameraControlsStyle`.

### Geometry
`NormalizedRect` is the stable `[0,1]` geometry primitive. `CapturedImageTransform` maps displayed normalized geometry back to raw captured-image coordinates, including rotation and horizontal mirroring. `PreviewGeometry` handles `BoxFit.cover` preview-to-source mapping before applying that transform.

### `src/frame/capture_frame.dart`
`CaptureFrame` supports ID-1, arbitrary aspect ratio + width factor, fixed size, or normalized rectangle. Auto-sized frames use `maxHeightFactor` and support optional `alignment` plus `alignmentPadding`.

`alignment == null` preserves centered behavior. `alignmentPadding` deflates the usable viewport before alignment and auto-size calculations, so top/bottom/side positioning can keep a configurable pitch from screen edges.

### `src/capture/capture_orientation_policy.dart`
`CaptureOrientationPolicy` supports `any`, `portraitOnly`, and `landscapeOnly`. It is a capture-surface policy only and never locks host OS orientation.

### `src/capture/card_capture_view.dart`
`CardCaptureView` remains camera-plugin agnostic. In a disallowed orientation the preview stays visible, the frame is hidden, and controller capture is disabled. `orientationMismatchBuilder` can render host guidance.

Frame style precedence is:
1. explicit `CardCaptureView.frameStyle`;
2. `CardScanTheme.of(context).captureFrameStyle`;
3. package defaults.

### `src/capture/card_capture_controller.dart`
`CardCaptureController` owns no camera hardware. `setCaptureEnabled(bool)` allows orientation policy to reject capture without detaching the camera delegate.

## Theme system

### `src/theme/card_scan_theme.dart`
`CardScanTheme` is the package `ThemeExtension`. Public class names do not repeat the `dxtr_card_scan` package prefix.

It groups:
- `captureFrameStyle`
- `imageCropStyle`
- `cameraControlsStyle`

It supports `copyWith`, `lerp`, and `CardScanTheme.of(context)` with a default fallback.

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

### `src/frame/capture_frame_style.dart`
`CaptureFrameStyle` controls Camera guide border, corner radius, and outside overlay.

### `src/crop/image_crop_style.dart`
`ImageCropStyle` controls Gallery crop overlay, border, handle fill/border, visible handle size, and gesture hit size.

### `src/theme/camera_controls_style.dart`
`CameraControlsStyle` controls example/host camera-control visuals: shutter size/shape/colors/border, normal and active Flash/Torch/Back colors, and Zoom badge colors. Nullable colors fall back to host `ColorScheme`.

## Manual image crop API

`ImageCropSelection` contains the host-provided image path plus a source-relative `NormalizedRect`.

`ImageCropView` accepts a local image path and resolves intrinsic dimensions with `FileImage`. `BoxFit.contain` geometry ensures letterbox regions never enter crop coordinates. Crop remains freeform for now; Roadmap tracks optional ratio/preset constraints.

Style precedence is per-widget `ImageCropView.style`, then `CardScanTheme.imageCropStyle`, then package defaults.

## Example application

`example/lib/main.dart` starts at `ExampleHomePage`:
- `Camera` -> `CameraCapturePage`
- `Gallery` -> example-owned `ImagePicker`, then `GalleryCropPage`

`image_picker` is an example dependency only.

Camera preview uses orientation-aware `BoxFit.cover`. Portrait controls are Back top-left, Flash beside it, Zoom top-center, Torch top-right, Shutter bottom-center. Landscape uses device orientation: shutter and Back share one edge, while Flash top / Zoom center / Torch bottom use the opposite edge.

Camera controls resolve `CardScanTheme.cameraControlsStyle`; Gallery crop resolves `CardScanTheme.imageCropStyle`.

## Naming rule

`Dxtr`/`dxtr` belongs only to the package/repository identity such as `dxtr_card_scan` and its import path. Dart classes, typedefs, fields, variables, helpers, test names, and UI-facing example labels must use domain names such as `CardScanTheme` rather than package-prefixed names.

## Validation status

Automated validation covers package analyze/tests, frame alignment/padding, orientation policy, theme resolution/interpolation, example analyze, generated Android/iOS host setup, and Android debug build.

Physical-device validation passed on 2026-08-22. The validated flow includes:
- Home -> Camera / Gallery
- Camera Back in portrait and both landscape orientations
- Flash / Torch / pinch zoom
- shutter and camera-control theming
- frame alignment/padding behavior
- orientation policy behavior
- Gallery picker -> crop -> Use crop
- custom `CardScanTheme` across Camera and Gallery

This completes the v0.1 implementation and device-validation boundary. The optional Gallery ratio/preset constraint remains a later enhancement and does not block v0.1.

## Next walkthrough section

v0.2 should document the Rust crate layout, Dart/FFI DTO boundary, image-buffer ownership, native error mapping, camera ROI vs manual Gallery ROI, and each preprocessing stage.
