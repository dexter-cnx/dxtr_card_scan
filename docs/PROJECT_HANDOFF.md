# Project Handoff

Last updated: 2026-08-19

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

## Current milestone

### v0.1 Capture foundation — implementation complete, awaiting CI/device validation

Branch: `agent/v0.1-capture-foundation`
PR: #2

Implemented:
- Flutter package scaffold
- `NormalizedRect`
- ID-1 and configurable `CaptureFrame`
- default `CaptureFrameStyle`
- fully custom `frameBuilder`
- camera-plugin-agnostic preview builder
- manual `CardCaptureController` with explicit lifecycle
- `BoxFit.cover` preview-to-captured-image geometry mapper
- explicit `CapturedImageTransform` for 0/90/180/270 degree rotation and horizontal mirroring
- geometry unit tests including rotation and mirroring
- real-camera example source using Flutter's official `camera` plugin
- GitHub Actions fast gate for package analyze/test and example analyze
- Makefile development commands
- architecture, roadmap, walkthrough, and handoff docs

Automated validation still required before merge:
- observe GitHub Actions results on PR #2
- fix any analyzer/test failures reported by CI

Manual validation gate after CI is green:
- generate/complete example platform scaffolding if needed
- run example on at least one physical Android or iOS device
- verify preview fills the intended capture surface
- verify ID-1 frame alignment in portrait
- rotate device and verify orientation behavior
- capture a card and record raw file pixel dimensions/orientation
- confirm frame-to-image ROI against the captured file

Stop before v0.2 implementation if v0.1 device geometry has not been validated. The Rust processor depends on this ROI contract.

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

Update both `docs/CODE_WALKTHROUGH.md` and this handoff whenever a material PR changes architecture, public API, native processing, platform support, or milestone status.
