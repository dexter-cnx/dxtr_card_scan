# Code Walkthrough

This document tracks the implementation as the package evolves. Update it with every material milestone.

## 0.1 Capture foundation

### `lib/dxtr_card_scan.dart`
The public barrel. Only intended public API is exported from here.

### `src/geometry/normalized_rect.dart`
`NormalizedRect` is the stable geometry primitive. It stores left/top/right/bottom in `[0,1]` space and converts to or from pixel `Rect` values for a known image size.

Normalized geometry is the boundary that will later cross into Rust. This avoids tying processing requests to a particular preview or sensor resolution.

### `src/geometry/captured_image_transform.dart`
`CapturedImageTransform` makes the camera orientation contract explicit. It describes how the raw captured image was rotated for display (`quarterTurnsClockwise`) and whether that displayed preview was horizontally mirrored.

`displayedToRaw` inverts those operations using the four rectangle corners, producing a normalized rectangle in raw captured-image coordinates. Mirroring is undone before the inverse rotation.

### `src/geometry/preview_geometry.dart`
`PreviewGeometry` first maps a frame drawn over a `BoxFit.cover` viewport into the orientation-normalized preview image. It then uses `CapturedImageTransform` to map that rectangle back into raw captured-image pixels or normalized raw coordinates.

This prevents two common scanner bugs:
1. applying viewport pixels directly to a higher-resolution capture;
2. cropping the wrong region after portrait rotation or a mirrored preview.

### `src/frame/capture_frame.dart`
`CaptureFrame` describes where the user should place the card. It supports an ID-1 preset, aspect ratio + viewport width factor, fixed size, or a normalized rectangle.

Automatically sized frames also use `maxHeightFactor`. Width remains the primary sizing input in portrait, while landscape viewports clamp the frame height and recompute width from the card aspect ratio. This keeps an ID-1 frame fully visible instead of extending above/below a short landscape viewport.

The ID-1 preset uses the 85.60:53.98 physical card ratio used by common identity-card-sized documents.

### `src/frame/capture_frame_style.dart`
Defines the default white frame, border width, corner radius, and dark outside overlay. Full replacement belongs to `frameBuilder` so consumers are not constrained by the built-in painter.

### `src/capture/card_capture_view.dart`
`CardCaptureView` composes a host-provided camera preview with the frame overlay. It deliberately does not import a camera plugin. It attaches the caller's capture delegate to `CardCaptureController` for the lifetime of the widget and detaches it when the view changes or disposes.

### `src/capture/card_capture_controller.dart`
`CardCaptureController` provides manual capture orchestration without owning camera hardware. It has an explicit `dispose` lifecycle and rejects capture/attach operations after disposal.

## Example camera adapter

`example/lib/main.dart` uses Flutter's official `camera` plugin as a reference integration. The core package remains camera-plugin agnostic.

### Preview

`_CoverCameraPreview` derives the displayed aspect ratio from the current viewport orientation and uses `FittedBox(fit: BoxFit.cover)` plus clipping. This preserves camera-preview proportions in portrait and landscape and avoids squeezing or persistent letterboxing.

A brief visual transition may still occur while the platform camera surface itself rotates; the device gate requires the settled preview to be correct.

### Physical-bottom control area

The example no longer overlays the shutter directly on the scan surface. The page is split into:

1. an `Expanded` capture area containing `CardCaptureView`; and
2. a separate bottom `SafeArea` containing `_CameraControls`.

Because the white frame is resolved only inside the capture area, the shutter, flash, torch, and zoom controls cannot overlap the scan frame in landscape.

### Flash and torch

The example stores still-photo flash mode separately from torch state:

- `FlashMode.off` -> Flash off
- `FlashMode.auto` -> Flash auto
- `FlashMode.always` -> Flash on for still capture
- `FlashMode.torch` -> continuous torch

When torch is disabled, the previously selected still-photo flash mode is restored. This avoids losing the user's off/auto/on selection after temporary torch use.

Camera exceptions are surfaced with a `SnackBar` so unsupported hardware capabilities do not fail silently.

### Zoom

On initialization the example queries:

- `getMinZoomLevel()`
- `getMaxZoomLevel()`

The device-reported range drives a slider. The preview also has a two-finger `GestureDetector`; pinch scale is multiplied by the zoom level captured at gesture start and clamped to the camera's supported range before calling `setZoomLevel()`.

This zoom implementation must be validated on a physical device because the future Rust ROI assumes the visible frame and captured image continue to correspond at non-1x zoom.

## Generated platform hosts

The repository intentionally does not commit generated Android/iOS host folders. `tool/bootstrap_example_platforms.sh` creates fresh host scaffolding using the installed Flutter SDK, copies Android/iOS hosts into `example/`, and injects the iOS `NSCameraUsageDescription` entry. Generated host folders are ignored by git.

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

The settled portrait/landscape preview geometry has been reported correct on device. v0.1.1 adds flash, torch, zoom, pinch zoom, and a dedicated physical-bottom control area. These camera controls require one targeted device pass before the capture contract is considered stable enough for v0.2.

## Next walkthrough section

v0.2 should document the Rust crate layout, Dart/FFI DTO boundary, image-buffer ownership, native error mapping, ROI construction, and each preprocessing stage.
