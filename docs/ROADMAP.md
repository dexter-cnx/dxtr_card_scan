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
- [x] settled physical-device preview geometry validation

## 0.1.1 Camera controls
- [x] keep capture controls outside the scan frame in portrait/landscape
- [x] flash off / auto / on
- [x] independent torch toggle
- [x] zoom slider using device min/max zoom levels
- [x] pinch-to-zoom in camera preview
- [ ] physical-device validation for flash, torch, zoom, and landscape control placement
- [ ] decide whether a stable camera-control abstraction belongs in core or an optional camera adapter before 1.0

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
