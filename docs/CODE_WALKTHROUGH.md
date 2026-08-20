# Code Walkthrough

This document tracks the implementation as the package evolves. Update it with every material milestone.

## 0.1 Capture foundation

### `lib/dxtr_card_scan.dart`
The public barrel. Only intended public API is exported from here.

### `src/geometry/normalized_rect.dart`
`NormalizedRect` is the stable geometry primitive. It stores left/top/right/bottom in `[0,1]` space and converts to or from pixel `Rect` values for a known image size.

### `src/geometry/captured_image_transform.dart`
`CapturedImageTransform` maps displayed normalized geometry back to raw captured-image coordinates, including rotation and horizontal mirroring.

### `src/geometry/preview_geometry.dart`
`PreviewGeometry` maps a frame over a `BoxFit.cover` preview into source-image geometry, then applies `CapturedImageTransform` to reach raw captured-image coordinates.

### `src/frame/capture_frame.dart`
`CaptureFrame` supports ID-1, aspect ratio + width factor, fixed size, or normalized rectangle. Auto-sized frames use `maxHeightFactor` so landscape height is clamped while preserving aspect ratio.

### `src/capture/card_capture_view.dart`
`CardCaptureView` composes a host-provided preview and customizable frame without importing a specific camera plugin.

### `src/capture/card_capture_controller.dart`
`CardCaptureController` provides manual capture orchestration and explicit lifecycle without owning camera hardware.

## 0.1.2 Manual image crop API

### `src/crop/image_crop_selection.dart`
`ImageCropSelection` is the Gallery equivalent of the camera ROI boundary. It contains:
- the host-provided image path; and
- a `NormalizedRect` representing the user-selected source-image region.

The model deliberately does not know how the image was selected.

### `src/crop/image_crop_view.dart`
`ImageCropView` accepts a local image path from the host and resolves the image's intrinsic dimensions with `FileImage`.

The widget uses `BoxFit.contain` geometry to calculate the actual displayed image rectangle. Crop geometry is relative to that rectangle, not the full widget viewport, so letterboxed areas never become part of the normalized crop.

The crop rectangle:
- starts inset from the image edges;
- can be dragged as a whole;
- has four draggable corner handles;
- enforces a minimum width/height;
- clamps every edge to `[0,1]`; and
- emits `ImageCropSelection` after every change.

No pixels are rewritten yet. v0.2 will take `imagePath + normalizedRect` and perform the actual deterministic crop/preprocessing in Rust.

## Example application

### Home routing

`example/lib/main.dart` now starts with `ExampleHomePage` rather than opening Camera immediately.

The two entry points are:
- `Camera` -> pushes `CameraCapturePage`.
- `Gallery` -> invokes `ImagePicker` in the example, then pushes `GalleryCropPage` with only `XFile.path`.

`image_picker` is therefore an example integration dependency, not a package dependency. A consuming app can substitute any picker/file browser/document source and still pass a path into `ImageCropView`.

### Gallery crop page

`GalleryCropPage` is a conventional secondary editor screen with an `AppBar`, system Back support, and a `Use crop` action. The page stores the latest `ImageCropSelection` and returns it through `Navigator.pop`.

### Camera preview

`_CoverCameraPreview` derives displayed aspect ratio from current viewport orientation and uses `FittedBox(fit: BoxFit.cover)` with clipping. Settled portrait and landscape preview geometry has already been validated on device.

### Camera zoom

The example queries device min/max zoom during camera initialization. Zoom is pinch-only. `_ZoomBadge` only displays current scale.

### Flash and torch

Still-photo flash mode is stored separately from torch state. Disabling torch restores the previous off/auto/on still-photo flash selection.

### Orientation-aware camera controls and Back

Camera remains full-screen even though it is now a secondary route.

Portrait:
- Back is top-left.
- Flash sits immediately to the right of Back.
- Zoom badge is top-center.
- Torch is top-right.
- Shutter is bottom-center.

Landscape uses `camera.value.deviceOrientation`:
- `landscapeLeft` -> shutter right.
- `landscapeRight` -> shutter left.
- Flash / zoom / Torch use the opposite edge.
- Flash is top-aligned, zoom vertically centered, Torch bottom-aligned.
- Back is top-center so navigation does not collide with either control edge.

The Navigator/system back gesture remains available in addition to the explicit Back affordance.

## Example picker/platform setup

`example/pubspec.yaml` contains `image_picker`; root `pubspec.yaml` does not.

`tool/bootstrap_example_platforms.sh` generates Android/iOS host scaffolding and injects:
- `NSCameraUsageDescription`
- `NSPhotoLibraryUsageDescription`

Generated platform folders remain uncommitted.

Useful commands:

```sh
make example-platforms
make example-build-android
```

## Automated validation

CI continues to gate:
- package analyze
- package unit tests
- example dependency resolution/analyze
- Android/iOS host generation
- Android debug APK build

## Manual validation boundary

The next physical-device pass should cover Home -> Camera -> Back, Home -> Gallery -> picker -> crop -> Use crop, plus existing flash/torch/pinch zoom and landscape control placement. Both Camera and Gallery must preserve normalized source-image ROI semantics before v0.2 freezes the Rust processing boundary.

## Next walkthrough section

v0.2 should document the Rust crate layout, Dart/FFI DTO boundary, image-buffer ownership, native error mapping, camera ROI vs manual Gallery ROI, and each preprocessing stage.
