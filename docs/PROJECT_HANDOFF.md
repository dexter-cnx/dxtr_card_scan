# Project Handoff

Last updated: 2026-08-26

## Project

Repository: `dexter-cnx/dxtr_card_scan`

`dxtr_card_scan` is an OCR-engine-agnostic Flutter/Dart SDK for card/document capture plus deterministic Rust preprocessing. Flutter owns capture UI/preview geometry. Rust owns deterministic raster processing.

## Architecture rules

1. Core does not embed an OCR engine.
2. Rust does not own camera lifecycle/UI.
3. Preview/frame geometry is normalized before processing.
4. Rotation/mirroring is explicit.
5. Default Camera and Gallery capture behavior belongs to the package; host apps configure the surfaces rather than reimplementing the pipeline.
6. Gallery/Camera labels are injectable so localization and wording stay host-controlled.
7. Host apps may replace the default Gallery picker through an escape-hatch callback without taking ownership of crop/process behavior.
8. Grayscale/OCR enhancement remains opt-in.
9. `Dxtr`/`dxtr` is reserved for package/repository identity; public Dart domain types remain neutral.
10. Camera detection is constrained by the capture-frame ROI before auto-detect.
11. CPU-heavy decode/orientation work and synchronous native FFI processing run off Flutter's UI isolate.
12. Camera-to-Gallery switching remains inside one capture flow and reuses the package-owned Gallery crop/processor pipeline.
13. Smart Capture thresholds remain calibration candidates until physical evidence supports production defaults.
14. Live-frame and final-capture geometry share one explicit coordinate model; digital zoom/crop, fit, rotation and mirroring are never inferred ad hoc by UI code.
15. Temporal stability is deterministic policy over quality + detected quad samples.
16. Auto-capture policy remains separate from camera ownership; the policy emits decisions and never invokes the shutter directly.

## Current status

- `v0.2` native processor foundation is complete and closed.
- SC-00 unified Camera/Gallery entry merged via PR #14 on 2026-08-26. Merge SHA: `062fc5dcb5deaf8d61b3649eb567ff0cae4e2b4c`.
- SC-01 live card quality assessment model merged via PR #15 on 2026-08-26. Merge SHA: `50040812d27ceb504b85589a871f3ce9239592d2`.
- SC-02 frame-to-sensor geometry merged via PR #16 on 2026-08-26. Merge SHA: `1d324af5a2264017bf5cb96e3ee3ce3c5cd33d10`.
- SC-03 blur + temporal stability merged via PR #17 on 2026-08-26. Merge SHA: `822bacd31832307dda27c4ea70115d441ab0846f`.
- Current work branch: `feature/sc04-quality-gated-auto-capture`.

## High-level capture surfaces

### Camera

`CardCaptureView` owns camera discovery/lifecycle, back-camera selection, preview, controls, orientation policy, frame rendering, capture, EXIF normalization, ROI mapping, native rectification, confirmation, processing and temporary intermediates.

### Gallery

`CardGalleryCaptureView` owns default source selection and processing. Android/iOS use `image_picker`; macOS uses `file_selector`; hosts can override only the source picker. `CardGalleryCropView` remains available when a host already owns the source path.

### SC-00 — Unified Camera/Gallery entry

`CardCameraGalleryCaptureView` keeps Camera as the initial surface and exposes Gallery directly from the Camera flow. Gallery selection enters the existing crop/native-processing pipeline and closing it returns to Camera.

## Smart Capture

### SC-01 — Live card quality model

The deterministic quality metrics have an advisory interpretation layer through `CardCaptureQualityIssue`, `CardCaptureQualityThresholds`, and `CardCaptureQualityAssessment`. Exposure uses both clipped fractions and mean luminance. Missing detection is not misreported as merely a small card.

### SC-02 — Frame-to-sensor geometry

`CameraGeometryMapper` models viewport size, raw sensor/image size, orientation/mirror transform, preview `BoxFit`, and `displayedCropRegion` for digital zoom/platform crop. Live analysis and final capture must use this same geometry contract.

### SC-03 — Blur + temporal stability

`CardCaptureStabilityTracker` accepts one `CardCaptureQualityAssessment` plus optional `CardScanDetection` per analyzed frame. Blur/missing/invalid detection resets the streak; spatial movement starts a new streak at the current valid frame. Corresponding corners are aligned across cyclic quad rotations before displacement is measured so detector start-corner jitter does not create false motion.

### SC-04 — Quality-gated auto capture

Current branch adds a pure decision layer:
- `CardAutoCaptureState`: `searching`, `detected`, `ready`, `cooldown`
- `CardAutoCaptureConfig`
- `CardAutoCaptureDecision`
- `CardAutoCapturePolicy`

Policy inputs are SC-01 quality plus SC-03 stability. Detection confidence determines `searching`; valid detection that has not cleared all gates is `detected`; clear quality + stable streak is `ready`.

Auto capture is **disabled by default**. When enabled, a ready decision emits `shouldCapture = true` and enters cooldown. The policy itself never calls `CardCaptureController` or owns camera lifecycle.

`minimumQualityScore` defaults to zero because the current aggregate score includes card coverage and is not yet physically calibrated for a universal readiness threshold. Explicit quality issues + temporal stability are the default gates; applications may opt into a score threshold after collecting evidence.

SC-04 still needs live camera frame-stream integration/throttling before end-to-end auto capture is complete.

## Processor/result representation

`CardCaptureImage` uses a file path as its primary representation and exposes `readBytes()` for consumers that need bytes.

`CardCaptureResult` currently exposes `original`, `cropped`, `processed`, and `sourceRoi`.

## Important validation lessons

1. Camera JPEG/display orientation must be normalized before ROI mapping.
2. Cyclic quad ordering must not introduce 180-degree warp flips.
3. Camera auto-detect should run inside the visible capture-frame ROI.
4. Heavy image preparation/FFI must not block Flutter's UI isolate.
5. macOS sandbox-selected files are read-only inputs; intermediates belong in temporary storage.
6. Unified Camera/Gallery source switching must happen above the shared crop/process pipeline.
7. Exposure guidance cannot rely only on clipped-pixel fractions.
8. A missing card detection must not be misreported as merely a small card.
9. Live geometry must account for preview fit, crop/zoom, rotation and mirroring explicitly.
10. Stability corner matching must tolerate cyclic detector corner ordering.
11. Aggregate quality score must not be assigned an uncalibrated high default readiness threshold because card coverage contributes directly to that score.

## Smart Capture roadmap

- SC-00 — Unified Camera/Gallery entry: merged.
- SC-01 — Live card quality model and advisory guidance: merged.
- SC-02 — Formal frame-to-sensor geometry mapping: merged; physical mapping evidence remains.
- SC-03 — Blur and temporal stability detection: merged; physical stability calibration remains.
- SC-04 — Quality-gated auto capture: decision/state/cooldown policy in progress; live stream integration remains.
- SC-05 — Glare detection, including OCR-sensitive card regions.
- SC-06 — Perspective/alignment score.
- SC-07 — Corner-confidence feedback UI.
- SC-08 — Quality metadata in `CardCaptureResult`.
- SC-09 — Capture behavior profiles (`ocr`, `fast`, `archival`, `manual`).
- SC-10 — Optional platform-native scanner fallback.

## Next milestone

Finish SC-04 CI/review, then integrate throttled live camera analysis using `CameraGeometryMapper`, quality assessment, stability tracker, and auto-capture policy without duplicating the final-capture ROI mapping.

Physical calibration remains required before non-zero aggregate score thresholds or aggressive auto-capture defaults are treated as production-ready.

## Documentation policy

Keep `docs/PROJECT_HANDOFF.md`, `docs/CODE_WALKTHROUGH.md`, and `docs/ROADMAP.md` synchronized for material capture/geometry/native-processing changes.
