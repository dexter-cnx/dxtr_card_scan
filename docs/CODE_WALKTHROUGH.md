# Code Walkthrough

This document tracks the implementation as the package evolves.

## Capture geometry foundation

`CameraGeometryMapper` is the SC-02 contract for mapping viewport/capture-frame geometry into raw sensor/image coordinates while accounting for preview `BoxFit`, orientation/mirroring, and digital-zoom/platform crop regions.

Live analysis and final capture must use the same mapping contract.

## Smart Capture

### Quality — `card_scan_quality_analysis.dart`

SC-01 interprets Rust blur, exposure, card coverage and detection-confidence measurements into advisory issues. Aggregate score is not a production auto-capture threshold by default.

### Stability — `card_capture_stability_tracker.dart`

SC-03 tracks sharpness-gated temporal stability using corresponding quad-corner displacement and card-coverage drift. Cyclic detector start-corner changes are aligned before movement is calculated.

### Auto-capture policy — `card_auto_capture_policy.dart`

SC-04 exposes `searching`, `detected`, `ready`, and `cooldown`. Auto capture is disabled by default. Policy evaluation does not invoke a camera controller; cooldown is committed only when a capture dispatch actually occurs.

### Live coordinator — `card_live_capture_coordinator.dart`

`CardLiveCaptureCoordinator`:
- throttles accepted analyzed samples
- composes SC-01 quality + SC-03 stability + SC-04 policy
- dispatches through an attached package capture delegate
- prevents re-entrant shutter dispatch
- recovers from backward wall-clock corrections

It accepts already-analyzed ROI samples and remains independent from raw camera formats.

### Raw stream adapter — `card_camera_image_adapter.dart`

`CardCameraImageAdapter` bridges Flutter camera-plugin stream frames to the encoded-image Rust ABI.

Public DTOs:
- `CardCameraFrameFormat`
- `CardCameraFramePlane`
- `CardCameraFrame`

`fromCameraImage()` copies plugin planes into an isolate-safe DTO. Supported layouts include BGRA8888, planar YUV420, and bi-planar YUV420. Row stride, luminance pixel stride, and chroma pixel stride are honored.

`encodeJpeg()` quantizes the normalized raw-frame ROI first, then converts only pixels inside that ROI and JPEG-encodes the ROI for Rust quality/detection analysis. Full high-resolution frames are not decoded before cropping.

The adapter intentionally does not rotate or mirror the stream frame. Preview-to-stream orientation must be resolved through the explicit SC-02 geometry contract and validated on physical Android/iOS devices.

### Live frame analyzer — `card_live_frame_analyzer.dart`

`CardLiveFrameAnalyzer` accepts a copied `CardCameraFrame` plus an already-mapped raw-frame ROI. `Isolate.run()` performs ROI conversion/JPEG encoding and one combined Rust frame-analysis call off the Flutter UI isolate. The returned `CardLiveAnalysisSample` is ready for `CardLiveCaptureCoordinator`.

### Live camera session — `card_live_camera_session.dart`

`CardLiveCameraSession` owns `CameraController.startImageStream()` and the backpressure boundary before expensive work begins. It:
- interval-gates frames before copying camera planes
- allows only one conversion/analysis operation in flight
- invalidates stale in-flight results across stop/restart generations
- resets coordinator stability/policy state when streaming stops
- reports non-fatal stream/analysis failures through an optional error callback
- requires an explicit `CardLiveFrameRoiResolver`, so orientation/mirroring/zoom mapping is never guessed inside the stream layer

This keeps four responsibilities separate:
1. `CardCaptureView` owns camera lifecycle, viewport geometry and capture UI.
2. `CardLiveCameraSession` owns stream lifecycle/backpressure.
3. `CardCameraImageAdapter` owns raw-plane conversion and ROI encoding.
4. `CardLiveFrameAnalyzer` owns worker-isolate Rust analysis.

## Rust processing

The Rust processor owns deterministic image processing and exposes C ABI entry points for processing, detection and quality analysis. Rust image APIs expect encoded image bytes; raw `CameraImage` planes must first pass through the stream adapter.

## Package-owned capture

`CardCaptureView` owns camera lifecycle, preview, controls, capture, EXIF normalization, ROI mapping, rectification, confirmation and final processing. `CardGalleryCaptureView`/`CardGalleryCropView` own Gallery flows.

The next increment wires `CardLiveCameraSession` into `CardCaptureView`: the view resolves the capture-frame ROI through SC-02, pauses/stops streaming around still capture/processing/confirmation, and attaches the package shutter delegate to `CardLiveCaptureCoordinator`.

## Validation tooling

CI covers Flutter analyze/tests, Example analyze/build and Rust format/Clippy/tests. Physical calibration remains mandatory before auto-capture defaults are enabled.

## Status

- SC-00 through SC-03 merged.
- SC-04 policy merged via PR #18.
- SC-04 live coordinator merged via PR #19.
- SC-04 raw CameraImage adapter merged via PR #20.
- SC-04 worker-isolate frame analysis merged via PR #21.
- Current increment adds the live camera stream session/backpressure boundary; `CardCaptureView` integration remains next.
