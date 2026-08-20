# Project Handoff

Last updated: 2026-08-20

## Project

Repository: `dexter-cnx/dxtr_card_scan`

Dxtr Card Scan is an OCR-engine-agnostic Flutter/Dart SDK for capturing cards/documents and preparing images for OCR. Flutter owns camera/UI/geometry. Rust owns deterministic preprocessing.

## Non-negotiable architecture decisions

1. Do not embed an OCR engine in the core package.
2. Do not let Rust own camera lifecycle or capture UI.
3. Do not crop captured images using raw Flutter preview coordinates.
4. Normalize preview/frame geometry before crossing the processing boundary.
5. Camera orientation/mirroring must be explicit; do not assume the captured file is already orientation-normalized.
6. Grayscale and hard thresholding are optional and should not be aggressive defaults.
7. Keep future `CardTemplate` and named OCR regions compatible with the normalized-coordinate model.
8. Camera-specific controls may be demonstrated by the official `camera` plugin example, but the core package must remain camera-plugin agnostic unless a stable adapter boundary is deliberately introduced.

## Current milestone

### v0.1 Capture foundation — settled preview geometry validated on device

Branch: `agent/v0.1-capture-foundation`
PR: #2

Confirmed on physical device:
- back camera opens
- portrait ID-1 frame is centered and proportionally reasonable
- settled portrait preview is no longer squeezed/stretched
- settled landscape preview/frame geometry is correct
- a short transient distortion may still appear during platform rotation; treat as UX polish unless it persists after settling

Implemented foundation:
- Flutter package scaffold
- `NormalizedRect`
- ID-1 and configurable `CaptureFrame`
- default `CaptureFrameStyle`
- fully custom `frameBuilder`
- camera-plugin-agnostic preview builder
- manual `CardCaptureController` with explicit lifecycle
- `BoxFit.cover` preview-to-captured-image geometry mapper
- explicit `CapturedImageTransform` for 0/90/180/270 degree rotation and horizontal mirroring
- geometry unit tests including rotation, mirroring, and landscape frame clamping
- real-camera example source using Flutter's official `camera` plugin
- generated-host bootstrap script for Android/iOS example platforms
- GitHub Actions fast gate for package analyze/test, example analyze, host scaffolding, and Android debug APK build
- Makefile development/build commands
- architecture, roadmap, walkthrough, and handoff docs

## v0.1.1 Camera controls — current work

Requested before starting Rust preprocessing:
- capture button must live in a dedicated physical-bottom control area and never overlap the scan frame in landscape
- flash modes: off / auto / on
- independent torch on/off
- zoom using device-reported min/max range
- pinch-to-zoom in the preview

Current implementation in the example:
- camera surface and scan frame occupy an `Expanded` capture area
- a separate `SafeArea` bottom control panel owns flash/torch/zoom/shutter controls
- flash uses `FlashMode.off`, `FlashMode.auto`, and `FlashMode.always`
- torch temporarily uses `FlashMode.torch` and restores the selected still-photo flash mode when disabled
- zoom reads `getMinZoomLevel()` / `getMaxZoomLevel()` and supports both a slider and two-finger pinch
- camera capability failures are surfaced instead of silently assuming every device supports every mode

Manual retest after CI:
1. In portrait, shutter controls remain below/outside the scan frame.
2. In landscape, shutter control is at the physical bottom and never inside the white ID-1 frame.
3. Flash off works.
4. Flash auto can be selected.
5. Flash on fires for still capture on a device that supports it.
6. Torch turns on/off independently and restores the previous flash selection when turned off.
7. Zoom slider reaches usable min/max values without errors.
8. Two-finger pinch zooms smoothly and stays within device min/max.
9. Settled preview geometry remains correct at non-1x zoom.

Do not begin v0.2 until this camera-control retest is complete. Zoom especially changes the camera field of view, so the preview/capture alignment must remain reliable before the Rust ROI contract is frozen.

## Next milestone: v0.2 Rust processor

Planned processing order:
1. orientation normalization
2. expected-frame ROI (+ configurable margin)
3. grayscale working copy for detection
4. blur/edge detection
5. contours and quadrilateral approximation
6. candidate scoring
7. perspective warp
8. crop
9. optional OCR-oriented enhancement
10. optional resize
11. output encoding

Do not introduce ML/AI detection in v0.2 unless classical CV proves insufficient with evidence.

## Future milestones

- v0.3 quality analysis: blur, exposure, coverage, confidence
- v0.4 live detection + optional auto-capture
- v0.5 `CardTemplate` + named OCR regions
- v1.0 stable API, Android/iOS/macOS, benchmarks and full example

## Documentation policy

Update both `docs/CODE_WALKTHROUGH.md` and this handoff whenever a material PR changes architecture, public API, native processing, platform support, milestone status, or validation state.
