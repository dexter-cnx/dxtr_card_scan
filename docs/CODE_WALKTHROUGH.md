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

## Smart Capture quality and stability

### `lib/src/processor/card_scan_quality_analysis.dart`

SC-01 interprets deterministic Rust quality measurements without triggering capture. `CardCaptureQualityAssessment` combines blur, exposure, card coverage and detector confidence into advisory issues and a conservative score. Exposure uses both mean luminance and clipping fractions; card-size guidance is emitted only when detection is trustworthy.

### `lib/src/capture/card_capture_stability_tracker.dart`

SC-03 adds a deterministic temporal layer over per-frame quality plus `CardScanDetection` quad geometry.

`CardCaptureStabilityConfig` controls:
- `requiredStableFrames`
- minimum sharpness
- minimum detection confidence
- maximum normalized corresponding-corner displacement
- maximum card-coverage delta

`CardCaptureStabilityTracker.addSample()` accepts one quality assessment and its optional detection. Blur, missing detection or low-confidence detection reset the streak to zero. Excessive movement or coverage drift resets the streak to one because the current valid frame becomes the next baseline. Accepted adjacent frames increment the streak.

`CardCaptureStabilitySnapshot` exposes:
- stable frame count
- required frame count
- progress
- max corner displacement
- coverage delta
- blocking stability issue
- `isStable`

This class intentionally does not own a `CameraController`, image streaming, throttling, cooldown or shutter invocation. SC-04 will compose those concerns around the deterministic quality/geometry/stability primitives.

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
- `CaptureFrame` -> geometry mapping -> normalized source ROI
- native auto-detection/perspective rectification
- optional post-rectification confirmation
- final processing

The host only supplies configuration and result presentation. `CardCaptureController` remains an escape hatch for programmatic shutter triggering without transferring camera ownership back to the host.

## High-level Gallery surfaces

`CardGalleryCaptureView` owns the default Gallery source selection. Android/iOS use `image_picker`; macOS uses `file_selector`; hosts can override the picker. `CardGalleryCropView` owns EXIF normalization, crop, Rust detection/rectification, optional confirmation and final processing.

## Native packaging

### Android
`android/CMakeLists.txt` maps `ANDROID_ABI` to the matching Rust target and links the Rust staticlib into `libdxtr_card_scan_processor.so`.

### iOS / macOS
The podspecs run the Rust build before compile, declare the generated archive as an Xcode output and force-load it in the plugin Pod target.

## Validation tooling

`make install-hooks` installs the tracked pre-push guard. CI covers Flutter analyze/tests, Example analyze/build and Rust format/Clippy/tests.

Generated build state such as `android/.cxx/`, generated example platform hosts, and `rust/target/` is ignored. `rust/Cargo.lock` remains committed.

## Naming rule

`Dxtr`/`dxtr` belongs only to package/repository identity. Public Dart domain classes remain neutral.

## Status

- v0.2 is complete and merged.
- SC-00 unified Camera/Gallery entry is merged.
- SC-01 advisory live-quality assessment model is merged.
- SC-02 frame-to-sensor geometry is merged.
- SC-03 blur + temporal stability implementation is in progress; it remains independent from camera streaming and auto-capture.
