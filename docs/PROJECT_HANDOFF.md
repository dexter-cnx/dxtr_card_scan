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
9. File/image picking belongs to the host/example. The package may accept an image path and expose crop geometry, but must not depend on an image picker.

## Current branch / PR

Branch: `agent/v0.1-capture-foundation`
PR: #2

## v0.1 Capture foundation

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

### Frame geometry contract

Camera and Gallery do not currently expose identical frame constraints:

- Camera uses `CaptureFrame`, which supports `aspectRatio`, `widthFactor`, `maxHeightFactor`, `fixedSize`, and `normalizedRect`.
- The example Camera currently uses `CaptureFrame.id1(widthFactor: .88, maxHeightFactor: .82)`, so its guide is locked to the ID-1 physical ratio `85.60 / 53.98` while adapting to viewport size.
- Gallery `ImageCropView` currently uses a normalized initial rectangle and freeform corner resizing. It does not yet lock a crop aspect ratio or fixed crop size.
- Gallery should remain capable of freeform cropping, but a future API should allow an optional ratio/preset so hosts can request the same ID-1 constraint used by Camera.

## v0.1.1 Camera controls

Current control UX contract:

### Portrait
- full-screen camera surface remains intact
- Back control at top-left because Camera is now a secondary screen
- Flash remains in the top-left group immediately after Back
- zoom scale badge at top-center
- Torch control at top-right
- shutter at physical bottom-center
- zoom is pinch-only; there is no zoom slider

### Landscape
- camera remains full-screen
- use `camera.value.deviceOrientation` to distinguish `landscapeLeft` / `landscapeRight`
- landscape-left: shutter on the right edge
- landscape-right: shutter on the left edge
- Back is anchored at the top of the same edge as the shutter, not top-center, so it stays outside the central scan frame
- controls live on the edge opposite the shutter
- Flash is anchored at the top of that opposite edge
- zoom scale remains centered vertically on that opposite edge
- Torch is anchored at the bottom of that opposite edge

Camera capabilities:
- Flash: off / auto / on
- Torch: independent on/off, restoring the selected still-photo flash mode when disabled
- Zoom: device min/max queried at initialization; two-finger pinch only
- current zoom shown as a compact `x` scale badge

## v0.1.2 Example home + Gallery crop flow

The example now starts on a home screen with two choices:

1. `Camera` -> opens the existing full-screen camera capture flow as a secondary route.
2. `Gallery` -> the example uses `image_picker`, then passes only the selected image path into the package crop UI.

Picker boundary:
- `image_picker` is an example dependency only.
- The core package does not import or depend on `image_picker`.
- iOS example host generation adds both camera and photo-library usage descriptions.

Package crop API:
- `ImageCropView(imagePath: ...)` loads a host-provided local image path.
- The crop rectangle can be moved and resized from all four corners.
- The selection is constrained to the displayed source image.
- `ImageCropSelection` returns the original image path plus a `NormalizedRect` in source-image coordinates.
- The package does not raster-crop/encode the file yet; v0.2 Rust processing will consume the path + normalized ROI and perform deterministic crop/preprocessing.

Navigation/back design:
- Gallery crop uses a normal `AppBar` Back affordance because it is a conventional secondary editor screen.
- Camera remains immersive/full-screen; Back is an overlay control so adding navigation does not shrink or distort the preview.
- Portrait Camera Back is top-left with Flash shifted immediately to its right.
- Landscape Camera Back uses the top of the same physical edge as the shutter, leaving the center of the scan frame unobstructed.
- System back/gesture navigation still works through the Navigator route.

## Automated validation required

Before device retest, latest CI must pass:
- package analyze
- package unit tests
- example dependencies/analyze
- Android/iOS host scaffolding generation
- Android debug APK build

## Next physical-device retest

Validate:
1. Home screen opens and Camera/Gallery routes are obvious.
2. Camera Back returns to Home in portrait and both landscape orientations.
3. Camera Back does not collide with Flash, Torch, zoom badge, shutter, or scan frame; in landscape it should sit at the top of the shutter edge.
4. Existing flash/torch/pinch zoom behavior remains correct.
5. Gallery opens the platform image picker.
6. Selected image opens in the package crop screen.
7. Crop rectangle can be moved.
8. All four crop corners can be resized and remain inside the image.
9. `Use crop` returns to Home successfully.
10. Crop remains aligned correctly for both portrait and landscape source images.

Do not begin v0.2 until this targeted device pass is complete. v0.2 will use the same normalized ROI boundary for both Camera capture and Gallery manual crop.

## Next milestone: v0.2 Rust processor

Planned processing order:
1. orientation normalization
2. expected-frame or manual-crop ROI (+ configurable margin when detection is used)
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
