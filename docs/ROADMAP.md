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

PR #9 was squash-merged to `main` on 2026-08-23 as `0805c55f5efb4aa513d7647777c7f3c140d40e85`.

## 0.3 Quality analysis
- [x] blur score
- [x] exposure
- [x] card coverage
- [x] detection confidence
- [x] measurement-only Rust ABI + Dart API
- [x] PR #10 implementation + CI/review
- [x] Camera/Gallery calibration harness
- [x] PR #11 calibration harness + EXIF-normalized evidence path
- [x] define representative physical-device evidence protocol
- [ ] collect representative physical-device calibration evidence
- [ ] document candidate readiness thresholds from evidence

PR #10 was squash-merged to `main` on 2026-08-23 as `0cac8fb9f53d7916433108c773fc0d8fc2162907`.
PR #11 was squash-merged to `main` on 2026-08-23 as `8a1a4d9ac5578442b866ee051eec6b5d3f0d097b`.

Quality analysis remains measurement-first. Default auto-capture readiness thresholds are not production-ready until representative physical-device calibration is collected.

## 0.4 Smart / live capture
- [x] SC-00 unified Camera/Gallery entry
- [x] SC-01 advisory live-quality assessment model and configurable thresholds
- [x] SC-02 public `CameraGeometryMapper` viewport -> raw sensor contract
- [x] SC-02 explicit `BoxFit.cover` / `BoxFit.contain` preview composition
- [x] SC-02 orientation/mirroring mapping through `CapturedImageTransform`
- [x] SC-02 digital zoom/platform crop support through `displayedCropRegion`
- [x] SC-02 regression coverage for cover, contain letterboxing, rotation and crop-region mapping
- [ ] SC-02 physical-device geometry/calibration evidence across supported orientations and zoom states
- [x] SC-03 blur gate for temporal stability samples
- [x] SC-03 corresponding-corner displacement tracking
- [x] SC-03 card-coverage drift tracking
- [x] SC-03 configurable stable-frame streak and deterministic reset behavior
- [x] SC-03 pure Dart regression coverage for stable, moved, blurry and missing-detection sequences
- [ ] SC-03 physical-device stability calibration
- [ ] SC-04 throttled live camera analysis integration
- [ ] SC-04 searching / detected / ready state machine
- [ ] SC-04 optional quality-gated auto-capture + cooldown
- [ ] SC-05 glare detection
- [ ] SC-06 perspective/alignment score
- [ ] SC-07 corner-confidence feedback UI
- [ ] SC-08 quality metadata in `CardCaptureResult`
- [ ] SC-09 capture profiles (`ocr`, `fast`, `archival`, `manual`)
- [ ] SC-10 optional native scanner fallback

SC-02 geometry contract: live frame/capture-frame ROIs use the same fitted-preview, orientation/mirroring and effective crop-region rules as final capture processing. `displayedCropRegion` represents digital zoom or platform camera crop in orientation-normalized displayed sensor space. Letterbox padding is never sensor content.

SC-03 stability contract: a frame contributes to a stable streak only when sharpness and detection confidence pass. Accepted adjacent frames must remain within configured corresponding-corner displacement and card-coverage delta limits. Spatial movement starts a new streak at the current valid frame; blur/missing/invalid detection resets the streak completely. Stability has no shutter side effects.

## 0.5 CardTemplate
- [ ] named normalized OCR regions
- [ ] region extraction after perspective correction

## 1.0
- [ ] stable public API
- [ ] validated Android/iOS/macOS support
- [ ] benchmarks
- [ ] full example app
- [ ] package documentation
