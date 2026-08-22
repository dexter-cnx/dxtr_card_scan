# Project Handoff

Last updated: 2026-08-22

## Project

Repository: `dexter-cnx/dxtr_card_scan`

`dxtr_card_scan` is an OCR-engine-agnostic Flutter/Dart SDK for capturing cards/documents and preparing images for OCR. Flutter owns camera/UI/geometry. Rust owns deterministic preprocessing.

## Non-negotiable architecture decisions

1. Do not embed an OCR engine in the core package.
2. Do not let Rust own camera lifecycle or capture UI.
3. Do not crop captured images using raw Flutter preview coordinates.
4. Normalize preview/frame geometry before crossing the processing boundary.
5. Camera orientation/mirroring must be explicit.
6. Grayscale and hard thresholding are optional and should not be aggressive defaults.
7. Keep future `CardTemplate` and named OCR regions compatible with normalized coordinates.
8. File/image picking belongs to the host/example. Core accepts image data/paths and normalized geometry but does not depend on an image picker.
9. Capture orientation policy must not lock the host application's OS orientation.
10. Camera and Gallery visuals inherit host theming through `CardScanTheme` plus host `ThemeData` / `ColorScheme`.
11. `Dxtr`/`dxtr` is reserved for package/repository identity. Public Dart domain types remain neutral.
12. v0.2 card detection remains classical CV and deterministic. Do not add ML/AI detection unless classical CV proves insufficient with evidence.
13. Perspective geometry is evaluated only after orientation normalization and optional raw ROI crop. A supplied `perspective_quad` is normalized to that current working image.

## Current branch / PR

Branch: `agent/v0.2-perspective-warp`
PR: pending

## v0.1 status

**Complete and merged. Physical-device validation passed on 2026-08-22.**

Validated on physical device:
- Camera / Gallery navigation
- portrait and both landscape camera control layouts
- Back outside scan frame
- flash off / auto / on
- torch
- pinch-only zoom + badge
- capture-frame alignment/padding
- portrait-only / landscape-only capture policy
- Gallery picker -> crop -> Use crop
- custom `CardScanTheme`

## v0.2 PR1 — Rust processor foundation

**Merged as PR #3.**

Implemented:
- Rust `cdylib` / `staticlib` / `rlib`
- JPEG/PNG decode
- explicit clockwise quarter-turn orientation normalization
- pixel-stable normalized ROI mapping and exact integer rotation
- crop
- optional grayscale
- no-upscale max-dimension resize
- JPEG/PNG output
- stable C ABI using UTF-8 JSON options
- explicit result ownership/free contract
- panic containment
- Rust format/clippy/test CI

## v0.2 PR2 — deterministic quadrilateral detection

**Merged as PR #4.**

Implemented:
1. grayscale working copy
2. deterministic 3x3 box blur
3. Sobel gradient magnitude
4. adaptive threshold
5. zero-gradient/solid-image rejection
6. 8-connected edge components
7. convex hull extraction
8. four-distinct-corner quad approximation that preserves 45-degree/diamond cases
9. deterministic candidate scoring

Candidate score components:
- area coverage
- rectangularity
- expected aspect-ratio similarity with portrait equivalence
- center alignment
- edge strength

`detect_card_quad()` remains usable independently and returns normalized clockwise corners plus score breakdown.

## v0.2 PR3 — perspective warp / OCR enhancement

**In progress on `agent/v0.2-perspective-warp`.**

Current implementation:
- `warp_quad()` performs deterministic projective mapping from a normalized clockwise quad into a rectified image.
- Warp sampling is inverse-mapped from destination to source with bilinear interpolation.
- Quad start index is not assumed to be top-left. The warp canonicalizes the cyclic corner order so the longer opposite-edge pair becomes output width, preserving landscape card orientation for portrait/diamond input.
- Natural output dimensions are derived from averaged opposite-edge lengths.
- optional `warp_long_edge` scales the rectified output while preserving aspect ratio.
- `process_encoded()` can use either `auto_detect: true` or a supplied `perspective_quad`; they are mutually exclusive.
- `perspective_quad` coordinates are normalized to the working image after orientation normalization and optional ROI crop.
- `enhance_for_ocr` is opt-in and performs grayscale conversion plus conservative 2nd/98th percentile contrast stretching.
- perspective warp occurs before OCR enhancement and before the existing max-dimension resize/output encoding stages.
- the C ABI function signatures remain unchanged; JSON options evolve backward-compatibly.

New `ProcessorOptions` fields:
- `auto_detect`
- `perspective_quad`
- `warp_long_edge`
- `enhance_for_ocr`

Local validation targets now include `make rust-format`, `make rust-format-check`, `make rust-clippy`, `make rust-test`, and `make rust-ci`.

## Remaining v0.2 order

After PR3 validation:
1. Dart FFI wrapper
2. Android/iOS/macOS native-library packaging
3. Flutter processor API and error mapping
4. example integration for Camera ROI / Gallery crop / auto-detect
5. physical-device validation

## Geometry contracts

Camera frame geometry uses normalized source-image coordinates after `BoxFit.cover` mapping plus explicit capture transform. Gallery crop uses source-relative normalized coordinates. Rust ROI is quantized once in raw pixel space before orientation rotation to avoid floating-point boundary drift.

The detector emits a cyclic clockwise quad. Consumers must not assume the first point is always top-left; PR3 warp handles the cyclic start internally.

## Documentation policy

Update both `docs/CODE_WALKTHROUGH.md` and this handoff whenever a material PR changes architecture, public API, native processing, platform support, milestone status, or validation state.
