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
- [x] SC-09 profile-driven `CardCaptureView` factory without breaking its const constructor
- [x] SC-10 platform-neutral native scanner fallback contract
- [x] SC-10 integrate injected native scanner into unified capture flow

SC-04 stream contract: raw `CameraImage` planes are never sent directly to Rust encoded-image APIs. `CardLiveCameraSession` owns `startImageStream()` lifecycle, interval gating and one-frame-in-flight backpressure. `CardCaptureView` owns the session, package shutter delegate and SC-02 viewport/frame mapping. Live streaming remains opt-in through an explicit `CardLiveStreamTransformResolver`; unresolved orientation/mirroring states skip analysis rather than guessing. Zoomed live analysis is also skipped until preview-to-stream crop mapping is physically calibrated. Still capture stops streaming before `takePicture()` and keeps it stopped through processing/confirmation, restarting only when the live camera surface is active again.

SC-05 glare remains measurement-only until physical evidence establishes a reliable acceptance threshold. The Rust measurement separates overall near-white neutral coverage from localized hotspot concentration so ordinary bright exposure is not treated as equivalent to specular glare.

SC-06 perspective/alignment analysis is derived from the existing detected quad in Dart, so it adds no native image-analysis pass. `perspectiveScore` combines opposite-edge length balance and opposite-edge parallelism; `alignmentScore` reuses the detector's center-alignment signal. Production thresholds remain calibration-gated.

SC-07 corner feedback is geometry-only. Per-corner confidence combines the detector's existing edge-strength signal with adjacent-edge orthogonality after restoring the exact analyzed ROI aspect ratio. `CardCaptureView` now owns a `CardLiveFeedbackController`, feeds it only accepted live-analysis samples, renders `CardLiveFeedbackOverlayLayer` in the resolved capture frame, and clears feedback whenever live streaming pauses or stops so stale geometry is never shown over still/confirmation states. The feedback path remains advisory-only and does not participate in stability, readiness, or auto-capture decisions.

SC-08 keeps result metadata optional so existing camera/gallery callers remain source-compatible. `CardCaptureQualityMetadata` carries the existing quality assessment, associated detection, and exact analyzed ROI aspect ratio without requiring another native image-analysis pass. `CardCaptureView` freezes the latest eligible accepted live sample immediately before pausing the image stream for shutter dispatch. Live UI/eligibility state can then be cleared without losing the capture snapshot; retake/capture failure clears it, while successful completion attaches it to `CardCaptureResult` and releases it afterward.

SC-09 introduces named processor presets for `manual`, `ocr`, `fast`, and `archival` capture goals. Built-in profiles deliberately leave automatic shutter dispatch disabled so profile selection cannot bypass physical calibration requirements. Profile wiring uses `CardCaptureProfile.<profile>.captureView(...)`, which applies the profile defaults at runtime while keeping the original `const CardCaptureView(...)` constructor unchanged. Explicit `processOptions` and `autoCapture` arguments remain authoritative over profile defaults.

SC-10 keeps native document-scanner SDKs behind an injected `CardNativeScanner` contract rather than coupling the package core to VisionKit, ML Kit, or another platform-specific dependency. `CardNativeScanResult` preserves page order and supports multi-page scans. `CardCameraGalleryCaptureView` queries scanner availability explicitly, exposes the scanner only when available, and feeds each scanned image through the existing `CardGalleryCropView` pipeline in page order. `onCompleted` is emitted once per processed page; closing the source flow cancels the remaining native-scan pages. `scan()` returning null remains a no-op user cancellation, and no second processing pipeline is introduced.

## 0.5 CardTemplate
- [x] named normalized OCR region model + validation
- [x] region extraction after perspective correction

`CardTemplate` is pure-Dart metadata over the perspective-corrected card coordinate space. It preserves template-defined region order, rejects empty/duplicate names and invalid normalized bounds, and remains independent from camera, UI, and FFI layers. `CardTemplateExtractor` consumes the already perspective-corrected encoded image produced by the existing processor path, decodes it once, crops every named region in template order with deterministic floor/ceil quantization, and returns PNG-encoded region bytes ready for OCR consumers without adding another native processing pass.

## 1.0
- [x] audit current root-barrel public API and define stability tiers
- [x] decide root-barrel disposition of low-level live/orchestration exports
- [x] add public API compatibility regression suite
- [x] document supported advanced API contracts
- [x] declaration-level audit of remaining root-barrel exports
- [x] neutral public-name audit
- [x] intentional public defaults/constructor audit
- [x] stable public API
- [ ] validated Android/iOS/macOS support
- [ ] benchmarks
- [ ] full example app
- [ ] package documentation

The primary compatibility surface lives in `dxtr_card_scan.dart`. Lower-level orchestration is deliberately available through `dxtr_card_scan_advanced.dart`, which re-exports the primary API plus the live session/coordinator/analyzer, stability state machine, package capture pipeline, and feedback-controller layer. `test/public_api_boundary_test.dart` guards this split. The final API contract, neutral naming result, and intentional 1.0 defaults are recorded in `docs/1.0_API_STABILITY_SIGNOFF.md`.

The `stable public API` checkbox covers the Dart API compatibility contract only. Physical calibration evidence, production thresholds, platform validation, benchmarks, example completeness, and package documentation remain separate release gates and are not implied complete by this sign-off.
