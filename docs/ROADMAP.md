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
- [x] bounded warp output size
- [x] optional OCR-oriented enhancement
- [x] optional resize
- [x] JPEG/PNG encoding
- [x] Dart FFI wrapper
- [x] Flutter processor API + native error mapping
- [x] Android build-time Rust packaging implementation
- [x] iOS build-time Rust packaging implementation
- [x] macOS build-time Rust packaging implementation
- [ ] Android native packaging CI validation
- [ ] iOS native linkage validation
- [ ] macOS native linkage validation
- [ ] Camera/Gallery example processor integration
- [ ] physical-device validation of native processor flow

## 0.3 Quality analysis
- [ ] blur score
- [ ] exposure
- [ ] card coverage
- [ ] detection confidence

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
