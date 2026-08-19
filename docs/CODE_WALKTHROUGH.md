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

The ID-1 preset uses the 85.60:53.98 physical card ratio used by common identity-card-sized documents.

### `src/frame/capture_frame_style.dart`
Defines the default white frame, border width, corner radius, and dark outside overlay. Full replacement belongs to `frameBuilder` so consumers are not constrained by the built-in painter.

### `src/capture/card_capture_view.dart`
`CardCaptureView` composes a host-provided camera preview with the frame overlay. It deliberately does not import a camera plugin. It attaches the caller's capture delegate to `CardCaptureController` for the lifetime of the widget and detaches it when the view changes or disposes.

### `src/capture/card_capture_controller.dart`
`CardCaptureController` provides manual capture orchestration without owning camera hardware. It has an explicit `dispose` lifecycle and rejects capture/attach operations after disposal.

## Example

`example/lib/main.dart` uses Flutter's official `camera` plugin to select a back camera, initialize a real preview, render the ID-1 frame, and trigger a still capture through `CardCaptureController`.

The repository intentionally does not commit generated Android/iOS host folders. `tool/bootstrap_example_platforms.sh` creates fresh host scaffolding using the installed Flutter SDK, copies Android/iOS hosts into `example/`, and injects the iOS `NSCameraUsageDescription` entry. Generated host folders are ignored by git.

Useful commands:

```sh
make example-platforms
make example-build-android
```

The example intentionally stops after image acquisition in v0.1. Rust preprocessing begins only after real-device geometry validation.

## Automated validation

- normalized coordinate round-trip test
- ID-1 frame geometry test
- `BoxFit.cover` center-crop mapping test
- clockwise rotation inverse-mapping test
- horizontal mirror inverse-mapping test
- package analyze GitHub Actions gate
- package unit-test GitHub Actions gate
- example dependency/analyze GitHub Actions gate
- Android/iOS host-scaffolding generation gate
- Android debug APK build gate

CI run `32208833946` completed all of the above successfully before the final documentation-only handoff updates.

## Manual validation boundary

The remaining uncertainty is platform camera behavior, not Dart compilation. A physical device must confirm how preview orientation and the captured JPEG orientation relate on Android/iOS. That observation decides the concrete `CapturedImageTransform` values supplied to the future processor.

Do not hide this behavior behind heuristics before device evidence exists.

## Next walkthrough section

v0.2 should document the Rust crate layout, Dart/FFI DTO boundary, image-buffer ownership, native error mapping, ROI construction, and each preprocessing stage.
