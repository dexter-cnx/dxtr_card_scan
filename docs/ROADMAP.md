# Roadmap

## 0.1 Capture foundation
- [x] Flutter package scaffold
- [x] camera-preview abstraction
- [x] customizable ID-1 capture frame
- [x] normalized geometry / `BoxFit.cover` mapping
- [x] configurable frame alignment + padding
- [x] portrait / landscape capture policy
- [x] Camera/Gallery theming and controls
- [x] physical-device validation baseline

## 0.2 Rust processor
- [x] stable C ABI
- [x] deterministic ROI crop / orientation normalization
- [x] quadrilateral detection and perspective correction
- [x] OCR-oriented enhancement / grayscale / resize / JPEG-PNG encoding
- [x] Flutter FFI wrapper
- [x] Android/iOS/macOS packaging and native validation

## 0.3 Quality analysis
- [x] blur score
- [x] exposure
- [x] card coverage
- [x] detection confidence
- [x] measurement-only Rust ABI + Dart interpretation
- [x] physical-evidence protocol
- [ ] collect representative physical-device calibration evidence
- [ ] promote calibrated readiness thresholds

## 0.4 Smart / live capture
- [x] SC-00 unified Camera/Gallery entry
- [x] SC-01 advisory quality assessment
- [x] SC-02 explicit viewport -> raw sensor geometry mapper
- [ ] SC-02 physical geometry evidence across orientation/zoom states
- [x] SC-03 blur-gated temporal stability
- [x] SC-03 cyclic-corner alignment + coverage drift
- [ ] SC-03 physical stability calibration
- [x] SC-04 searching/detected/ready/cooldown policy
- [x] SC-04 opt-in auto-capture decision
- [x] SC-04 live capture coordinator + throttling + single-flight shutter guard
- [x] SC-04 cooldown only on actual capture dispatch
- [x] SC-04 raw CameraImage adapter DTO boundary
- [x] SC-04 YUV420 + BGRA8888 conversion
- [x] SC-04 raw-frame ROI crop + JPEG encode for Rust analysis
- [x] SC-04 worker-isolate live frame analyzer for Rust quality/detection
- [ ] SC-04 wire `startImageStream()` into `CardCaptureView`
- [ ] SC-04 preview-to-stream orientation/geometry physical validation
- [ ] SC-04 end-to-end physical auto-capture validation
- [ ] SC-05 glare detection
- [ ] SC-06 perspective/alignment score
- [ ] SC-07 corner-confidence feedback UI
- [ ] SC-08 quality metadata in `CardCaptureResult`
- [ ] SC-09 capture profiles (`ocr`, `fast`, `archival`, `manual`)
- [ ] SC-10 optional native scanner fallback

SC-04 stream contract: raw `CameraImage` planes are never sent directly to Rust encoded-image APIs. The adapter honors plane strides, crops an ROI already mapped into raw-frame coordinates, then JPEG-encodes that ROI. `CardLiveFrameAnalyzer` performs conversion + Rust quality/detection on a worker isolate. Rotation/mirroring remains explicit and must be resolved by the SC-02 geometry contract before extraction.

## 0.5 CardTemplate
- [ ] named normalized OCR regions
- [ ] region extraction after perspective correction

## 1.0
- [ ] stable public API
- [ ] validated Android/iOS/macOS support
- [ ] benchmarks
- [ ] full example app
- [ ] package documentation
