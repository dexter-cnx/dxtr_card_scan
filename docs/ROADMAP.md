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
- [x] SC-04 camera stream session with pre-throttle + single-frame-in-flight
- [x] SC-04 wire live stream session into `CardCaptureView`
- [ ] SC-04 preview-to-stream orientation/geometry physical validation
- [ ] SC-04 end-to-end physical auto-capture validation
- [x] SC-05 advisory glare measurement (`specularFraction`, `peakTileFraction`, `score`)
- [ ] SC-05 physical glare calibration + production threshold
- [x] SC-06 advisory perspective/alignment geometry analysis
- [ ] SC-06 physical perspective/alignment calibration + threshold
- [x] SC-07 reusable corner-confidence model + overlay UI
- [x] SC-07 accepted-sample feedback controller bridge
- [x] SC-07 reusable live feedback overlay listener layer
- [x] SC-07 wire live feedback into `CardCaptureView`
- [x] SC-08 optional quality metadata contract in `CardCaptureResult`
- [x] SC-08 snapshot eligible live analysis at shutter time
- [x] SC-09 capture profile preset contract (`ocr`, `fast`, `archival`, `manual`)
- [ ] SC-09 wire profiles into `CardCaptureView` with explicit overrides
- [ ] SC-10 optional native scanner fallback

SC-04 stream contract: raw `CameraImage` planes are never sent directly to Rust encoded-image APIs. `CardLiveCameraSession` owns `startImageStream()` lifecycle, interval gating and one-frame-in-flight backpressure. `CardCaptureView` owns the session, package shutter delegate and SC-02 viewport/frame mapping. Live streaming remains opt-in through an explicit `CardLiveStreamTransformResolver`; unresolved orientation/mirroring states skip analysis rather than guessing. Zoomed live analysis is also skipped until preview-to-stream crop mapping is physically calibrated. Still capture stops streaming before `takePicture()` and keeps it stopped through processing/confirmation, restarting only when the live camera surface is active again.

SC-05 glare remains measurement-only until physical evidence establishes a reliable acceptance threshold. The Rust measurement separates overall near-white neutral coverage from localized hotspot concentration so ordinary bright exposure is not treated as equivalent to specular glare.

SC-06 perspective/alignment analysis is derived from the existing detected quad in Dart, so it adds no native image-analysis pass. `perspectiveScore` combines opposite-edge length balance and opposite-edge parallelism; `alignmentScore` reuses the detector's center-alignment signal. Production thresholds remain calibration-gated.

SC-07 corner feedback is geometry-only. Per-corner confidence combines the detector's existing edge-strength signal with adjacent-edge orthogonality after restoring the exact analyzed ROI aspect ratio. `CardCaptureView` now owns a `CardLiveFeedbackController`, feeds it only accepted live-analysis samples, renders `CardLiveFeedbackOverlayLayer` in the resolved capture frame, and clears feedback whenever live streaming pauses or stops so stale geometry is never shown over still/confirmation states. The feedback path remains advisory-only and does not participate in stability, readiness, or auto-capture decisions.

SC-08 keeps result metadata optional so existing camera/gallery callers remain source-compatible. `CardCaptureQualityMetadata` carries the existing quality assessment, associated detection, and exact analyzed ROI aspect ratio without requiring another native image-analysis pass. `CardCaptureView` freezes the latest eligible accepted live sample immediately before pausing the image stream for shutter dispatch. Live UI/eligibility state can then be cleared without losing the capture snapshot; retake/capture failure clears it, while successful completion attaches it to `CardCaptureResult` and releases it afterward.

SC-09 introduces named processor presets for `manual`, `ocr`, `fast`, and `archival` capture goals. Built-in profiles deliberately leave automatic shutter dispatch disabled; profile selection must not bypass the physical calibration requirements that govern live auto-capture. The follow-up wiring keeps explicit `CardCaptureView` options authoritative so existing callers remain compatible.

## 0.5 CardTemplate
- [ ] named normalized OCR regions
- [ ] region extraction after perspective correction

## 1.0
- [ ] stable public API
- [ ] validated Android/iOS/macOS support
- [ ] benchmarks
- [ ] full example app
- [ ] package documentation
