# Roadmap

## 0.1 Capture foundation
- [x] Flutter package scaffold
- [x] camera-preview abstraction
- [x] customizable capture frame
- [x] ID-1 aspect-ratio preset
- [x] normalized frame geometry
- [x] configurable frame alignment with optional alignment padding
- [x] capture orientation policy: any / portrait-only / landscape-only
- [x] shared `CardScanTheme` ThemeExtension for Camera and Gallery visuals
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
- [x] themed shutter / Back / Flash / Torch / Zoom badge controls
- [x] physical-device validation for flash, torch, zoom, shutter, Back, theme, and landscape control placement
- [ ] decide whether a stable camera-control abstraction belongs in core or an optional camera adapter before 1.0

## 0.1.2 Gallery crop flow
- [x] example home screen with Camera and Gallery entries
- [x] image picker dependency lives only in the example
- [x] package `ImageCropView` accepts a host-provided image path
- [x] draggable/resizable crop rectangle
- [x] package returns `ImageCropSelection` with normalized source-image geometry
- [x] secondary-screen back navigation for Gallery crop
- [x] secondary-screen back control for full-screen Camera flow
- [x] Gallery crop visuals inherit `CardScanTheme.imageCropStyle`
- [x] physical-device validation for Gallery selection/crop and Camera back placement
- [ ] optional Gallery ratio/preset constraint matching Camera frame constraints

## 0.1 completion gate
- [x] automated CI passes
- [x] physical-device validation passes
- [x] naming cleanup complete (`Dxtr`/`dxtr` reserved for package/repository identity)
- [x] Roadmap / Code Walkthrough / Project Handoff synchronized

## 0.2 Rust processor
- [x] Rust crate and stable C ABI boundary
- [x] orientation normalization
- [x] ROI from capture frame or manual Gallery crop selection
- [x] grayscale working copy
- [x] blur / Sobel edge detection
- [x] connected components and convex hull extraction
- [x] quadrilateral approximation and deterministic scoring
- [x] zero-gradient false-positive rejection
- [x] 45-degree/diamond corner-tie regression handling
- [x] deterministic projective perspective correction
- [x] detected/manual quad crop through warp
- [x] optional OCR-oriented grayscale contrast enhancement
- [x] optional grayscale
- [x] optional resize
- [x] JPEG/PNG output encoding
- [ ] Dart FFI wrapper
- [ ] Android native-library packaging
- [ ] iOS native-library packaging
- [ ] macOS native-library packaging
- [ ] Flutter processor API + native error mapping
- [ ] Camera/Gallery example integration
- [ ] physical-device validation of native processor flow

## 0.3 Quality analysis
- blur score
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
