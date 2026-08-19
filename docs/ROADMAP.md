# Roadmap

## 0.1 Capture foundation
- [x] Flutter package scaffold
- [x] camera-preview abstraction
- [x] customizable capture frame
- [x] ID-1 aspect-ratio preset
- [x] normalized frame geometry
- [x] `BoxFit.cover` preview-to-image mapping
- [x] explicit captured-image rotation/mirroring contract
- [x] manual capture controller abstraction
- [x] geometry unit tests
- [x] real-camera example source
- [x] CI analyze/test gate
- [ ] physical-device preview/capture geometry validation

## 0.2 Rust processor
- Rust crate and FFI boundary
- orientation normalization
- ROI from capture frame
- quadrilateral detection
- perspective correction
- crop
- optional grayscale
- optional resize

## 0.3 Quality analysis
- blur
- exposure
- card coverage
- detection confidence

## 0.4 Live detection
- throttled analysis
- searching/detected/ready states
- stability tracking
- optional auto-capture

## 0.5 CardTemplate
- named normalized OCR regions
- region extraction after perspective correction

## 1.0
- stable public API
- Android/iOS/macOS support
- benchmarks
- full example app
- package documentation
