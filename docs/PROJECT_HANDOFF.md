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
8. Camera-specific controls may be demonstrated by the official `camera` plugin example, but the core package remains camera-plugin agnostic unless a stable adapter boundary is deliberately introduced.

## Current milestone

### v0.1 Capture foundation — settled preview geometry validated on device

Branch: `agent/v0.1-capture-foundation`
PR: #2

Confirmed on physical device:
- back camera opens
- portrait ID-1 frame is centered and proportionally reasonable
- settled portrait preview is not squeezed/stretched
- settled landscape preview/frame geometry is correct
- short transient distortion can appear during rotation, but settled preview is correct

Implemented foundation:
- Flutter package scaffold
- normalized geometry and preview-to-image mapping
- explicit captured-image rotation/mirroring contract
- configurable ID-1 frame with landscape height clamping
- camera-plugin-agnostic capture view/controller
- real-camera reference example using Flutter `camera`
- CI analyze/test/example/Android-build gates
- docs, roadmap, walkthrough, handoff

## v0.1.1 Camera controls — current work

Current control UX contract:

### Portrait
- full-screen camera surface remains intact
- Flash control at top-left
- zoom scale badge at top-center
- Torch control at top-right
- shutter at physical bottom-center
- zoom is pinch-only; there is no zoom slider

### Landscape
- camera remains full-screen; do not reserve half the screen for a bottom control panel
- use `camera.value.deviceOrientation` to distinguish `landscapeLeft` / `landscapeRight`
- landscape-left: shutter on the right edge
- landscape-right: shutter on the left edge
- Flash / zoom scale / Torch form a vertical stack on the edge opposite the shutter
- controls remain outside the white scan frame as a UX requirement, even though they overlay the full-screen preview surface

Camera capabilities:
- Flash: off / auto / on
- Torch: independent on/off, restoring the selected still-photo flash mode when disabled
- Zoom: device min/max queried at initialization; two-finger pinch only
- current zoom shown as a compact `x` scale badge
- unsupported camera operations surface an error instead of silently failing

Manual retest after CI:
1. Portrait: Flash left / zoom scale center / Torch right.
2. Portrait: shutter is bottom-center and does not obscure the scan frame.
3. Landscape-left: shutter is on the right edge.
4. Landscape-right: shutter is on the left edge.
5. Landscape: Flash / zoom / Torch are vertically stacked on the edge opposite shutter.
6. Landscape still uses the full camera viewport; no half-screen control panel or persistent black band.
7. Flash off/auto/on behave as expected.
8. Torch toggles and restores prior flash mode.
9. Pinch zoom works without a slider and stays inside device min/max.
10. Zoom badge updates while pinching.
11. Settled preview/frame geometry remains correct at non-1x zoom.

Do not begin v0.2 until this targeted camera-control retest is complete. Zoom changes field of view, so preview/capture alignment must remain reliable before freezing the Rust ROI contract.

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
