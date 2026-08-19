# Code Walkthrough

This document tracks the implementation as the package evolves. Update it with every material milestone.

## 0.1 Capture foundation

### `lib/dxtr_card_scan.dart`
The public barrel. Only intended public API should be exported from here.

### `src/geometry/normalized_rect.dart`
`NormalizedRect` is the stable geometry primitive. It stores left/top/right/bottom in `[0,1]` space and converts to or from pixel `Rect` values for known image sizes.

Why this matters: the visible camera preview and captured sensor image are usually different resolutions and may be center-cropped.

### `src/geometry/preview_geometry.dart`
`PreviewGeometry` maps a frame drawn over a `BoxFit.cover` preview back into source-image coordinates. This prevents the common bug of directly applying preview-space pixels to the captured image.

Current assumption: captured image orientation has already been normalized. Rotation/mirroring metadata will be added before the Rust boundary is finalized.

### `src/frame/capture_frame.dart`
`CaptureFrame` describes where the user should place the card. It supports an ID-1 preset, an aspect ratio, a viewport width factor, fixed size, or a normalized rectangle.

The ID-1 preset uses the physical 85.60:53.98 card ratio used by common identity-card-sized documents.

### `src/frame/capture_frame_style.dart`
Defines the default white frame, border width, corner radius, and dark outside overlay. It is intentionally small because full customization belongs to `frameBuilder`.

### `src/capture/card_capture_view.dart`
`CardCaptureView` composes a host-provided preview with the frame overlay. It does not import a camera plugin. A caller can replace the overlay entirely using `frameBuilder`.

### `src/capture/card_capture_controller.dart`
`CardCaptureController` exposes manual capture while delegating the actual image acquisition to the host camera implementation. This keeps the core package independent from one camera plugin during API stabilization.

## Tests

The initial tests cover normalized coordinate round-tripping, ID-1 frame geometry, and center-crop mapping from preview space to image space.

## Next walkthrough section

v0.2 should document the Rust crate layout, Dart/FFI DTO boundary, ownership of image buffers, error mapping, and each preprocessing stage.
