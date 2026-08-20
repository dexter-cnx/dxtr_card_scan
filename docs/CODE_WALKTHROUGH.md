# Code Walkthrough

This document tracks the implementation as the package evolves. Update it with every material milestone.

## 0.1 Capture foundation

### `lib/dxtr_card_scan.dart`
The public barrel. Only intended public API is exported from here.

### `src/geometry/normalized_rect.dart`
`NormalizedRect` is the stable geometry primitive. It stores left/top/right/bottom in `[0,1]` space and converts to or from pixel `Rect` values for a known image size.

Normalized geometry is the boundary that will later cross into Rust. This avoids tying processing requests to a particular preview or sensor resolution.

### `src/geometry/captured_image_transform.dart`
`CapturedImageTransform` makes camera orientation explicit and maps displayed normalized geometry back to raw captured-image coordinates, including rotation and horizontal mirroring.

### `src/geometry/preview_geometry.dart`
`PreviewGeometry` maps a frame drawn over a `BoxFit.cover` preview into source-image geometry, then applies `CapturedImageTransform` to reach raw captured-image coordinates.

### `src/frame/capture_frame.dart`
`CaptureFrame` supports ID-1, aspect ratio + width factor, fixed size, or normalized rectangle. Auto-sized frames also use `maxHeightFactor`, so landscape height is clamped while preserving the card aspect ratio.

### `src/capture/card_capture_view.dart`
`CardCaptureView` composes a host-provided preview and customizable frame without importing a specific camera plugin.

### `src/capture/card_capture_controller.dart`
`CardCaptureController` provides manual capture orchestration and explicit lifecycle without owning camera hardware.

## Example camera adapter

`example/lib/main.dart` uses Flutter's official `camera` plugin as the reference integration. The core package remains camera-plugin agnostic.

### Preview

`_CoverCameraPreview` derives the displayed aspect ratio from the current viewport orientation and uses `FittedBox(fit: BoxFit.cover)` with clipping. Settled portrait and landscape preview geometry has been validated on a physical device.

### Zoom

The example queries device min/max zoom during camera initialization. Zoom is pinch-only: the gesture captures the zoom value at scale start, multiplies by the two-finger scale factor, clamps to device bounds, and calls `setZoomLevel()`.

There is intentionally no zoom slider. `_ZoomBadge` only displays the current scale, for example `1.0×` or `2.3×`.

### Flash and torch

Still-photo flash mode is stored separately from torch state:
- `FlashMode.off`
- `FlashMode.auto`
- `FlashMode.always`
- temporary `FlashMode.torch`

When torch is disabled, the previously selected still-photo flash mode is restored.

### Orientation-aware controls

`_OrientationCameraControls` overlays controls on the full-screen capture surface rather than shrinking the camera viewport.

Portrait layout:
- `_FlashMenu` at top-left
- `_ZoomBadge` at top-center
- `_TorchButton` at top-right
- `_ShutterButton` at bottom-center

Landscape layout uses `camera.value.deviceOrientation`, not safe-area heuristics:
- `DeviceOrientation.landscapeLeft` -> shutter on right
- `DeviceOrientation.landscapeRight` -> shutter on left
- Flash / zoom / Torch are vertically stacked on the opposite edge

This keeps the camera full-screen and matches the physical-bottom control expectation for either landscape rotation.

## Generated platform hosts

`tool/bootstrap_example_platforms.sh` generates Android/iOS host scaffolding for the example and injects required camera permission metadata. Generated platform folders are intentionally not committed.

Useful commands:

```sh
make example-platforms
make example-build-android
```

## Automated validation

- normalized coordinate round-trip test
- ID-1 portrait frame geometry test
- ID-1 landscape max-height clamp test
- `BoxFit.cover` center-crop mapping test
- clockwise rotation inverse-mapping test
- horizontal mirror inverse-mapping test
- package analyze GitHub Actions gate
- package unit-test GitHub Actions gate
- example dependency/analyze GitHub Actions gate
- Android/iOS host-scaffolding generation gate
- Android debug APK build gate

## Manual validation boundary

The next physical-device pass must validate orientation-aware control placement, flash/torch behavior, pinch-only zoom, zoom-badge updates, and preview/frame correctness at non-1x zoom. v0.2 should not freeze the Rust ROI contract until that pass is complete.

## Next walkthrough section

v0.2 should document the Rust crate layout, Dart/FFI DTO boundary, image-buffer ownership, native error mapping, ROI construction, and each preprocessing stage.
