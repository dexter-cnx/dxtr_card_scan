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
5. Grayscale and hard thresholding are optional and should not be aggressive defaults.
6. Keep future `CardTemplate` and named OCR regions compatible with the normalized-coordinate model.

## Current milestone

### v0.1 Capture foundation

Implemented on branch `agent/v0.1-capture-foundation`:
- Flutter package scaffold
- `NormalizedRect`
- ID-1 and configurable `CaptureFrame`
- default `CaptureFrameStyle`
- fully custom `frameBuilder`
- camera-plugin-agnostic preview builder
- manual `CardCaptureController`
- `BoxFit.cover` preview-to-captured-image geometry mapper
- initial geometry tests
- architecture, roadmap, walkthrough, and handoff docs

Still expected before v0.1 is considered complete:
- example app using a real Flutter camera plugin
- analyze/test CI
- validation on portrait/landscape and at least one real device
- explicit rotation/mirroring geometry contract

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
