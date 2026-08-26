# Code Walkthrough

This document tracks the implementation as the package evolves.

## Capture geometry foundation

`NormalizedRect`, `PreviewGeometry`, `CapturedImageTransform`, and `CameraGeometryMapper` keep Camera/Gallery geometry in explicit normalized coordinate systems. `CaptureFrame`, orientation policy, capture-frame styling and crop styling remain Flutter-owned.

### `lib/src/geometry/camera_geometry_mapper.dart`

`CameraGeometryMapper` maps viewport-space frame/live-analysis ROIs into normalized raw sensor/image coordinates while accounting for preview `BoxFit`, orientation/mirroring, and `displayedCropRegion` digital zoom/platform crop. Letterbox padding is not treated as sensor content.

## Smart Capture quality and stability

### `lib/src/processor/card_scan_quality_analysis.dart`

SC-01 interprets deterministic Rust quality measurements without triggering capture. `CardCaptureQualityAssessment` combines blur, exposure, card coverage and detector confidence into advisory issues and a conservative score.

### `lib/src/capture/card_capture_stability_tracker.dart`

SC-03 adds deterministic temporal stability over quality plus `CardScanDetection` quad geometry. It gates on sharpness/detection confidence, tracks coverage drift, and aligns cyclic quad corner order before calculating maximum corresponding-corner displacement.

`CardCaptureStabilitySnapshot` exposes stable-frame count, progress, movement measurements, blocking issue, and `isStable`.

### `lib/src/capture/card_auto_capture_policy.dart`

SC-04 composes SC-01 quality and SC-03 stability into a pure state machine:
- `searching` — no trustworthy detection
- `detected` — card detected but quality/stability gate not ready
- `ready` — explicit quality issues are clear and stability is ready
- `cooldown` — a prior enabled auto-capture decision is inside its cooldown window

`CardAutoCaptureConfig.enabled` defaults to `false`, preserving manual capture behavior. `minimumQualityScore` defaults to zero because the current SC-01 aggregate score contains card coverage and is not yet calibrated as a universal readiness threshold. Applications can opt into a non-zero score gate after collecting physical evidence.

`CardAutoCapturePolicy.evaluate()` returns `CardAutoCaptureDecision`; it never invokes `CardCaptureController` and never owns camera lifecycle. When enabled, a ready decision emits `shouldCapture = true`, then subsequent evaluations remain in cooldown until the configured duration expires.

The remaining SC-04 integration step is throttled camera image analysis wired to the package-owned camera surface using the SC-02 geometry contract.

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

`CardScanProcessor` owns Dart-side FFI allocation/copy/free behavior and exposes `processBytes()` / `processFile()` while mapping native failures to `CardScanProcessorException`.

Library loading:
- Android: `DynamicLibrary.open('libdxtr_card_scan_processor.so')`
- iOS/macOS: `DynamicLibrary.process()`

## Package-owned high-level capture pipeline

`CardCaptureView` owns Camera lifecycle, preview, controls, orientation, capture, EXIF normalization, ROI mapping, rectification, confirmation and final processing. `CardGalleryCaptureView` / `CardGalleryCropView` own Gallery selection/crop/process behavior.

`CardCaptureResult` exposes `original`, `cropped`, `processed`, and `sourceRoi`.

## Native packaging

Android links the Rust staticlib into `libdxtr_card_scan_processor.so`. iOS/macOS pod targets build and force-load the generated Rust archive.

## Validation tooling

`make install-hooks` installs the tracked pre-push guard. CI covers Flutter analyze/tests, Example analyze/build and Rust format/Clippy/tests.

## Naming rule

`Dxtr`/`dxtr` belongs only to package/repository identity. Public Dart domain classes remain neutral.

## Status

- v0.2 is complete and merged.
- SC-00 unified Camera/Gallery entry is merged.
- SC-01 advisory live-quality assessment model is merged.
- SC-02 frame-to-sensor geometry is merged.
- SC-03 blur + temporal stability is merged.
- SC-04 quality-gated decision/state/cooldown policy is in progress; live camera frame integration remains.
