# Code Walkthrough

This document tracks the implementation as the package evolves.

## Capture geometry foundation

`NormalizedRect`, `PreviewGeometry`, `CapturedImageTransform`, and `CameraGeometryMapper` keep Camera/Gallery geometry in explicit normalized coordinate systems. `CaptureFrame`, orientation policy, capture-frame styling and crop styling remain Flutter-owned.

### `lib/src/geometry/camera_geometry_mapper.dart`

`CameraGeometryMapper` is the SC-02 contract for mapping a viewport-space frame or live-analysis ROI into normalized raw sensor/image coordinates.

It models four pieces explicitly:
- `viewportSize` — Flutter preview layout size.
- `sensorSize` — raw camera image/sensor dimensions.
- `fit` — preview composition (`BoxFit.cover` by default, `contain` supported for letterboxed layouts).
- `displayedCropRegion` — normalized crop in orientation-normalized sensor space, used for platform crop regions and digital zoom.

Orientation and preview mirroring are handled by `CapturedImageTransform`. The mapper first resolves the visible fitted preview, maps the viewport rectangle into the effective displayed crop, expands that local crop back into displayed sensor coordinates, then transforms it to raw sensor coordinates.

Public outputs:
- `viewportRectToSensor()` -> `NormalizedRect` in raw sensor/image space.
- `viewportRectToSensorPixels()` -> raw pixel `Rect`.

A viewport rectangle that lies completely outside a `BoxFit.contain` preview is rejected rather than silently mapping letterbox padding into the sensor. Partial overlap is clipped to the visible preview. SC-03/SC-04 must consume this mapper so live quality analysis and final capture ROI use one geometry contract.

## Rust processing

### `rust/src/model.rs`
`ProcessorOptions` covers orientation, raw ROI, auto detection/manual quad, bounded warp size, OCR enhancement, grayscale, resize, and JPEG/PNG output.

### `rust/src/processor.rs`
Pipeline:
1. decode
2. quantize raw ROI
3. normalize orientation
4. rotate/crop ROI
5. detect or consume perspective quad
6. perspective warp/crop
7. optional OCR enhancement/grayscale
8. optional resize
9. encode

### `rust/src/detection.rs`
Deterministic classical-CV detector: grayscale, blur, Sobel, adaptive threshold, flat-image rejection, connected components, convex hull, distinct-corner quad approximation, scoring.

### `rust/src/warp.rs`
Deterministic projective rectification with cyclic-corner handling, long-edge-first orientation, source-top preservation, bilinear sampling, allocation bounds, and degenerate/singular rejection.

### `rust/src/ffi.rs`
Stable C ABI:
- `card_scan_process`
- `card_scan_result_free`

Input is encoded image bytes plus UTF-8 JSON options. Output/error memory remains Rust-owned until the result is freed.

## Dart FFI boundary

### `lib/src/processor/card_scan_processor_options.dart`
Public DTOs mirror the Rust JSON contract without exposing Rust implementation types:
- `CardScanProcessorOptions`
- `ProcessorPoint`
- `ProcessorQuad`
- `ProcessorOutputFormat`

### `lib/src/processor/card_scan_processor.dart`
`CardScanProcessor` owns Dart-side FFI allocation/copy/free behavior. It exposes `processBytes()` and `processFile()`, converts options to UTF-8 JSON, copies Rust output before freeing the native result, and maps native failures to `CardScanProcessorException`.

Library loading:
- Android: `DynamicLibrary.open('libdxtr_card_scan_processor.so')`
- iOS/macOS: `DynamicLibrary.process()`

## Package-owned high-level capture pipeline

### `lib/src/capture/card_capture_pipeline.dart`
Shared Camera/Gallery pipeline:
1. read source image
2. decode + EXIF `bakeOrientation()` on `Isolate.run()`
3. write normalized JPEG to system temporary storage
4. crop/rectify through `CardScanProcessor` on a worker isolate
5. optionally run final enhancement/grayscale/resize/encoding on a worker isolate
6. describe generated files as `CardCaptureImage`

The package does not force byte buffers through every callback. `CardCaptureImage` is file-backed (`path`, `width`, `height`) and exposes `readBytes()` only when the consumer needs bytes.

### `CardCaptureResult`
The final result keeps all useful stages:
- `original` — full captured/selected image before crop
- `cropped` — perspective-rectified card before final enhancement
- `processed` — final configured processor output
- `sourceRoi` — normalized source region used for rectification

## High-level Camera surface

### `lib/src/capture/card_capture_view.dart`
`CardCaptureView` owns the complete default Camera behavior:
- camera discovery and back-camera selection
- CameraController lifecycle across app pause/resume
- cover preview
- pinch zoom
- flash off/auto/on
- torch
- orientation-aware shutter placement
- Back control
- frame rendering and orientation policy
- image capture
- background EXIF normalization
- `CaptureFrame` -> `PreviewGeometry` -> normalized source ROI mapping
- native auto-detection/perspective rectification
- optional post-rectification confirmation
- final processing

The host only supplies configuration and result presentation:
- `CaptureFrame`
- `CardScanProcessorOptions`
- `CaptureConfirmationMode`
- `CardCaptureControlsConfig`
- `CardCaptureLabels`
- theme/frame overrides
- `onRawCaptured`, `onCropReady`, `onCompleted`

`CardCaptureController` remains an escape hatch for programmatic shutter triggering without transferring camera ownership back to the host.

## High-level Gallery surfaces

### `lib/src/crop/card_gallery_capture_view.dart`
`CardGalleryCaptureView` owns the default Gallery flow including source selection:
- Android/iOS: `image_picker`
- macOS: `file_selector`
- optional `pickImagePath` override for custom host pickers

After selection it delegates to `CardGalleryCropView`.

### `lib/src/crop/card_gallery_crop_view.dart`
`CardGalleryCropView` owns:
1. EXIF normalization
2. normalized temporary source
3. `ImageCropView`
4. manual normalized ROI
5. Rust auto-detect + perspective rectification
6. optional confirmation
7. final processing
8. staged callbacks/final result

This lower high-level surface is useful when an application already has an image path but still wants the package to own crop/process behavior.

## Customizable user-visible text

### `lib/src/ui/card_scan_labels.dart`
Package behavior never requires the Example to fork widgets merely to localize wording.

`CardCaptureLabels` configures Camera/confirmation text such as:
- Close/Back tooltip
- Flash off/auto/on
- Torch
- processing/error text
- confirmation title/action
- Retake

`GalleryCropLabels` configures:
- page title
- picker empty state/action
- crop instruction
- preparation/processing text
- Scan action
- confirmation/retry actions
- error prefix

Host applications can therefore use their own localization system while keeping Camera/Gallery behavior package-owned.

## Example structure after PR #9

The integrated Example demonstrates the public high-level API rather than duplicating package internals.

- `camera_scan_page.dart` configures frame, processor options, labels, confirmation mode and result preview only.
- `gallery_scan_page.dart` configures processor options, labels, confirmation mode and result preview only.
- Example no longer owns CameraController lifecycle, ROI mapping, native FFI execution, Gallery crop state, or default Gallery picker behavior.

The old helper/demo files may remain temporarily for validation/reference but are no longer part of the default integrated flow.

## Native packaging

### Android
`android/CMakeLists.txt` maps `ANDROID_ABI` to the matching Rust target and links the Rust staticlib into `libdxtr_card_scan_processor.so`.

### iOS / macOS
The podspecs run the Rust build before compile, declare the generated archive as an Xcode output and force-load it in the plugin Pod target. The host Runner links the plugin product rather than referencing a not-yet-generated archive directly.

## Validation tooling

`make install-hooks` installs the tracked pre-push guard. CI covers Flutter analyze/tests, Example analyze/build and Rust format/Clippy/tests.

Generated build state such as `android/.cxx/`, generated example platform hosts, and `rust/target/` is ignored. `rust/Cargo.lock` remains committed.

## Naming rule

`Dxtr`/`dxtr` belongs only to package/repository identity. Public Dart domain classes remain neutral.

## Status

- v0.2 is complete and merged.
- SC-00 unified Camera/Gallery entry is merged.
- SC-01 advisory live-quality assessment model is merged.
- SC-02 introduces the public frame-to-sensor geometry contract used by later live analysis and auto-capture work.
