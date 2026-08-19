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

### v0.1 Capture foundation — automated gates green, awaiting physical-device validation

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

Automated validation status:
- package dependencies: PASS
- package analyze: PASS
- package unit tests: PASS
- example dependencies: PASS
- example analyze: PASS
- Android/iOS host scaffolding generation: PASS
- Android example `flutter build apk --debug`: PASS
- latest successful workflow run: CI #6 / run 32208833946

## Manual validation gate — CURRENT STOP POINT

Do not begin v0.2 Rust processing until this gate is complete because the Rust ROI contract depends on real camera orientation behavior.

From the repository root:

```sh
git checkout agent/v0.1-capture-foundation
flutter pub get
make example-platforms
cd example
flutter pub get
flutter devices
flutter run -d <physical-device-id>
```

Validate on at least one physical Android or iOS device:
1. Camera opens without permission/lifecycle errors.
2. Back-camera preview is visible and usable.
3. White ID-1 frame is centered and sized sensibly in portrait.
4. Put a physical card inside the frame and capture it.
5. Captured image is produced successfully.
6. Rotate the device and report whether the preview/frame remains correctly oriented.
7. Report device/platform plus whether preview appears cropped, stretched, letterboxed, mirrored, or rotated incorrectly.
8. If possible, report captured JPEG pixel dimensions and whether the JPEG itself is portrait or landscape when inspected outside the app.

If any geometry/orientation issue appears, fix v0.1 before merge. If this gate passes, mark PR #2 ready/merge and proceed to v0.2 Rust processor.

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
