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

Before starting quality metrics, move end-to-end capture behavior behind package-owned high-level surfaces so host apps configure rather than reimplement the pipeline.

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
- [ ] collect representative physical-device calibration evidence
- [ ] document candidate readiness thresholds from evidence

PR #10 was squash-merged to `main` on 2026-08-23 as `0cac8fb9f53d7916433108c773fc0d8fc2162907`.

Quality analysis is measurement-only first. Do not couple thresholds to live auto-capture until calibration evidence is stable.

## 0.4 Live detection
- [ ] throttled analysis
- [ ] searching/detected/ready states
- [ ] stability tracking
- [ ] optional auto-capture

## 0.5 CardTemplate
- [ ] named normalized OCR regions
- [ ] region extraction after perspective correction

## 1.0
- [ ] stable public API
- [ ] validated Android/iOS/macOS support
- [ ] benchmarks
- [ ] full example app
- [ ] package documentation
