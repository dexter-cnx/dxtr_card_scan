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
13. Smart Capture quality interpretation remains advisory until physical calibration supports capture gating.
14. Live-frame and final-capture geometry must share one explicit coordinate model; digital zoom/crop, fit, rotation and mirroring cannot be inferred ad hoc by UI code.

## Current status

- `v0.2` native processor foundation is complete and closed.
- SC-00 unified Camera/Gallery entry merged via PR #14 on 2026-08-26. Merge SHA: `062fc5dcb5deaf8d61b3649eb567ff0cae4e2b4c`.
- SC-01 live card quality assessment model merged via PR #15 on 2026-08-26. Merge SHA: `50040812d27ceb504b85589a871f3ce9239592d2`.
- Current work branch: `feature/sc02-frame-sensor-geometry`.

## High-level capture surfaces

### Camera

`CardCaptureView` owns camera discovery/lifecycle, back-camera selection, preview, controls, orientation policy, frame rendering, capture, EXIF normalization, ROI mapping, native rectification, confirmation, processing and temporary intermediates.

### Gallery

`CardGalleryCaptureView` owns default source selection and processing. Android/iOS use `image_picker`; macOS uses `file_selector`; hosts can override only the source picker. `CardGalleryCropView` remains available when a host already owns the source path.

### SC-00 — Unified Camera/Gallery entry

`CardCameraGalleryCaptureView` keeps Camera as the initial surface and exposes Gallery directly from the Camera flow. Gallery selection enters the existing crop/native-processing pipeline and closing it returns to Camera. The shortcut is disabled during camera post-crop confirmation so it cannot overlap Retake/Confirm.

## Smart Capture

### SC-01 — Live card quality model

The existing deterministic quality metrics now have an advisory interpretation layer:
- `CardCaptureQualityIssue`
- `CardCaptureQualityThresholds`
- `CardCaptureQualityAssessment`
- conservative aggregate score
- deterministic `primaryIssue` for UI guidance

Exposure interpretation uses both clipped fractions and mean luminance. `cardTooSmall` is emitted only when card detection is trustworthy; no-detection frames prioritize `lowDetectionConfidence`.

SC-01 deliberately has no shutter side effects and does not start a camera image stream.

### SC-02 — Frame-to-sensor geometry

Current implementation branch adds `CameraGeometryMapper` as the explicit mapping boundary for live capture geometry.

Inputs:
- viewport size
- raw sensor/image size
- orientation/mirror transform
- preview `BoxFit`
- `displayedCropRegion` in orientation-normalized sensor coordinates, representing platform crop/digital zoom

Outputs:
- viewport rectangle -> normalized raw sensor rectangle
- viewport rectangle -> raw sensor pixel rectangle

This model is designed so SC-03/SC-04 can analyze the exact same ROI represented by the visible capture frame rather than using a second coordinate system for live frames.

Tests cover:
- `BoxFit.cover` crop mapping
- digital-zoom/crop-region mapping
- rotated raw sensor mapping
- `BoxFit.contain` letterbox rejection

Physical calibration evidence should record mapping inputs and expected ROI overlays on real devices before auto-capture is enabled.

## Processor/result representation

`CardCaptureImage` uses a file path as its primary representation and exposes `readBytes()` for consumers that need bytes.

`CardCaptureResult` currently exposes:
- `original`
- `cropped`
- `processed`
- `sourceRoi`

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

## Smart Capture roadmap

- SC-00 — Unified Camera/Gallery entry: merged.
- SC-01 — Live card quality model and advisory guidance: merged.
- SC-02 — Formal frame-to-sensor geometry mapping and calibration evidence: in progress.
- SC-03 — Blur and temporal stability detection.
- SC-04 — Quality-gated auto capture.
- SC-05 — Glare detection, including OCR-sensitive card regions.
- SC-06 — Perspective/alignment score.
- SC-07 — Corner-confidence feedback UI.
- SC-08 — Quality metadata in `CardCaptureResult`.
- SC-09 — Capture behavior profiles (`ocr`, `fast`, `archival`, `manual`).
- SC-10 — Optional platform-native scanner fallback.

## Next milestone

Finish SC-02 CI/review, then collect physical mapping evidence on representative Android/iOS devices. Continue to SC-03 temporal stability only after the live ROI mapping contract is stable.

Keep quality analysis and geometry deterministic and testable. Do not couple them to auto-capture until physical-device evidence supports the thresholds and mapping assumptions.

## Documentation policy

Keep `docs/PROJECT_HANDOFF.md`, `docs/CODE_WALKTHROUGH.md`, and `docs/ROADMAP.md` synchronized for material capture/geometry/native-processing changes.
