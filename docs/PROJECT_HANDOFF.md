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

## Current milestone

### v0.1 Capture foundation — first device pass completed, targeted retest required

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
- generated-host bootstrap script for Android/iOS example platforms
- GitHub Actions fast gate for package analyze/test, example analyze, host scaffolding, and Android debug APK build
- Makefile development/build commands
- architecture, roadmap, walkthrough, and handoff docs

## First physical-device findings

Confirmed working:
- back camera opens
- portrait ID-1 frame is centered and proportionally reasonable

Issues observed:
1. Portrait preview was visibly squeezed, as if a portrait camera image had been forced into a landscape aspect ratio.
2. Landscape frame height exceeded the screen, leaving black/empty preview area inside the frame.
3. During device rotation the preview visibly distorted briefly before settling.

Fixes now applied:
- example preview uses orientation-aware displayed aspect ratio with `FittedBox(fit: BoxFit.cover)` and clipping rather than a fixed `AspectRatio`
- `CaptureFrame` now supports `maxHeightFactor` and clamps auto-sized frames in short landscape viewports while preserving the card aspect ratio
- added a landscape frame-clamp unit test

## Automated validation

The earlier baseline passed:
- package dependencies: PASS
- package analyze: PASS
- package unit tests: PASS
- example dependencies: PASS
- example analyze: PASS
- Android/iOS host scaffolding generation: PASS
- Android example `flutter build apk --debug`: PASS

After the preview/frame fixes, CI must pass again before the targeted retest.

## Manual validation gate — CURRENT STOP POINT AFTER CI

Do not begin v0.2 Rust processing until this retest is complete because the Rust ROI contract depends on real camera orientation behavior.

Retest only these items:
1. Portrait preview is no longer squeezed/stretched.
2. Portrait ID-1 frame remains centered and sensible.
3. Landscape frame remains fully inside the visible screen.
4. No black/empty band appears inside the capture frame once rotation settles.
5. Landscape preview is not stretched.
6. Rotate portrait -> landscape -> portrait and report whether distortion remains only transient or persists after settling.
7. Capture at least one image in portrait and, if possible, landscape.
8. Report captured JPEG pixel dimensions and whether each JPEG opens as portrait or landscape outside the app.

If settled preview geometry is correct, a short transient platform-surface distortion during rotation can be treated separately as UX polish rather than blocking the Rust ROI contract. Persistent stretch/crop/letterbox remains a v0.1 blocker.

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
