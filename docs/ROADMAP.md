# Roadmap

## 0.1 Capture foundation
- [x] Flutter package scaffold
- [x] camera-preview abstraction
- [x] customizable capture frame
- [x] ID-1 aspect-ratio preset
- [x] normalized frame geometry
- [x] configurable frame alignment with optional alignment padding
- [x] capture orientation policy: any / portrait-only / landscape-only
- [x] shared `DxtrCardScanTheme` ThemeExtension for Camera and Gallery visuals
- [x] per-widget style override above inherited package theme
- [x] `BoxFit.cover` preview-to-image mapping
- [x] explicit captured-image rotation/mirroring contract
- [x] manual capture controller abstraction
- [x] geometry/orientation/theme unit tests
- [x] real-camera example source
- [x] CI analyze/test gate
- [x] settled physical-device preview geometry validation

## 0.1.1 Camera controls
- [x] full-screen orientation-aware camera controls
- [x] flash off / auto / on
- [x] independent torch toggle
- [x] pinch-only zoom using device min/max zoom levels
- [x] current zoom scale badge
- [ ] physical-device validation for flash, torch, zoom, and landscape control placement
- [ ] decide whether a stable camera-control abstraction belongs in core or an optional camera adapter before 1.0

## 0.1.2 Gallery crop flow
- [x] example home screen with Camera and Gallery entries
- [x] image picker dependency lives only in the example
- [x] package `ImageCropView` accepts a host-provided image path
- [x] draggable/resizable crop rectangle
- [x] package returns `ImageCropSelection` with normalized source-image geometry
- [x] secondary-screen back navigation for Gallery crop
- [x] secondary-screen back control for full-screen Camera flow
- [x] Gallery crop visuals inherit `DxtrCardScanTheme.imageCropStyle`
- [ ] optional Gallery ratio/preset constraint matching Camera frame constraints
- [ ] physical-device validation for Gallery selection/crop and Camera back placement

## 0.2 Rust processor
- Rust crate and FFI boundary
- orientation normalization
- ROI from capture frame or manual gallery crop selection
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
