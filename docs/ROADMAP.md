# Roadmap

## 0.1 Capture foundation
- [x] Flutter package scaffold
- [x] camera-preview abstraction
- [x] customizable ID-1 capture frame
- [x] normalized geometry / `BoxFit.cover` mapping
- [x] configurable frame alignment + padding
- [x] any / portrait-only / landscape-only capture policy
- [x] `CardScanTheme` for Camera/Gallery
- [x] explicit capture rotation/mirroring contract
- [x] Camera controls: Back / flash / torch / zoom / shutter
- [x] host-owned Gallery picker + package crop view
- [x] physical-device validation

## 0.2 Rust processor
- [x] Rust crate + stable C ABI
- [x] orientation normalization
- [x] pixel-stable ROI crop
- [x] grayscale / blur / Sobel
- [x] connected components + convex hull
- [x] deterministic quadrilateral detection/scoring
- [x] flat-image and 45-degree regressions
- [x] deterministic perspective warp/crop
- [x] source-top-preserving warp orientation
- [x] bounded warp output size
- [x] optional OCR-oriented enhancement
- [x] optional resize
- [x] JPEG/PNG encoding
- [x] Dart FFI wrapper
- [x] Flutter processor API + native error mapping
- [x] Android build-time Rust packaging implementation
- [x] iOS build-time Rust packaging implementation
- [x] macOS build-time Rust packaging implementation
- [x] Android native packaging CI validation
- [x] iOS native linkage validation
- [x] macOS native linkage validation
- [x] dedicated Camera/Gallery native processor validation example
- [x] isolate-backed image preparation/native processing
- [x] Android physical Camera + Gallery validation
- [x] iPhone physical Camera + Gallery validation
- [x] macOS Gallery/native processor validation
- [x] record v0.2 validation evidence
- [x] merge PR #7 and close v0.2

v0.2 closed on 2026-08-22. PR #7 merged as `6b8b1bbeb4455e1d411926d8b7c56239f4a127e5` after CI and Android/iPhone/macOS validation passed.

## Capture API ownership refactor

- [x] `CardCaptureView` owns Camera discovery/lifecycle/preview
- [x] package-owned Back / flash / torch / zoom / shutter controls
- [x] package-owned EXIF normalization + frame ROI mapping
- [x] package-owned rectification + final processor execution
- [x] staged original / rectified / processed result model
- [x] optional post-rectification confirmation
- [x] package-owned Gallery picker with custom-picker escape hatch
- [x] package-owned Gallery crop / rectify / process flow
- [x] configurable Camera and Gallery labels for host localization
- [x] CI + physical-device regression validation
- [x] merge PR #9

## 0.3 Quality analysis
- [x] blur score
- [x] exposure
- [x] card coverage
- [x] detection confidence
- [x] measurement-only Rust ABI + Dart API
- [x] Camera/Gallery calibration harness
- [x] representative physical-device evidence protocol
- [ ] collect representative physical-device calibration evidence
- [ ] document candidate readiness thresholds from evidence

Quality analysis remains measurement-first. Default auto-capture readiness thresholds are not production-ready until representative physical-device calibration is collected.

## 0.4 Smart / live capture
- [x] SC-00 unified Camera/Gallery entry
- [x] SC-01 advisory live-quality assessment model and configurable thresholds
- [x] SC-02 public `CameraGeometryMapper` viewport -> raw sensor contract
- [x] SC-02 preview fit + orientation/mirroring + digital zoom/platform crop mapping
- [ ] SC-02 physical-device geometry/calibration evidence across supported orientations and zoom states
- [x] SC-03 blur gate for temporal stability samples
- [x] SC-03 cyclic-corner-aligned quad displacement + card-coverage drift tracking
- [x] SC-03 configurable stable-frame streak and deterministic reset behavior
- [ ] SC-03 physical-device stability calibration
- [x] SC-04 `searching` / `detected` / `ready` / `cooldown` decision state machine
- [x] SC-04 optional auto-capture decision; disabled by default
- [x] SC-04 cooldown policy
- [x] SC-04 aggregate score gate is opt-in pending calibration
- [ ] SC-04 throttled live camera analysis integration
- [ ] SC-04 wire ready decisions to package-owned shutter path
- [ ] SC-04 physical auto-capture validation
- [ ] SC-05 glare detection
- [ ] SC-06 perspective/alignment score
- [ ] SC-07 corner-confidence feedback UI
- [ ] SC-08 quality metadata in `CardCaptureResult`
- [ ] SC-09 capture profiles (`ocr`, `fast`, `archival`, `manual`)
- [ ] SC-10 optional native scanner fallback

SC-02 geometry contract: live frame/capture-frame ROIs use the same fitted-preview, orientation/mirroring and effective crop-region rules as final capture processing.

SC-03 stability contract: sharpness and detection confidence gate samples; cyclic detector start-corner changes are aligned before displacement measurement. Spatial movement starts a new streak at the current valid frame; blur/missing/invalid detection resets completely.

SC-04 policy contract: quality/stability primitives feed a pure decision state machine. The policy never owns camera lifecycle or invokes the shutter. Auto capture remains opt-in and `minimumQualityScore` defaults to zero until physical calibration supports a non-zero aggregate threshold.

## 0.5 CardTemplate
- [ ] named normalized OCR regions
- [ ] region extraction after perspective correction

## 1.0
- [ ] stable public API
- [ ] validated Android/iOS/macOS support
- [ ] benchmarks
- [ ] full example app
- [ ] package documentation
