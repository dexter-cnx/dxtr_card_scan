# Code Walkthrough

This document tracks the implementation as the package evolves. Update it with every material milestone.

## 0.1 Capture foundation

### `lib/dxtr_card_scan.dart`
The public barrel. `dxtr_card_scan` is the package/library name; public Dart types intentionally avoid a package-name prefix. Exported APIs include `CaptureOrientationPolicy`, `CardScanTheme`, `CaptureFrameStyle`, `ImageCropStyle`, and `CameraControlsStyle`.

### Geometry
`NormalizedRect` is the stable `[0,1]` geometry primitive. `CapturedImageTransform` maps displayed normalized geometry back to raw captured-image coordinates, including rotation and horizontal mirroring. `PreviewGeometry` handles `BoxFit.cover` preview-to-source mapping before applying that transform.

### Capture/theme/gallery
`CaptureFrame` supports ratio, size, alignment, and alignment padding. `CaptureOrientationPolicy` rejects capture without locking host orientation. `CardScanTheme` owns package-specific Camera/Gallery visuals while standard controls continue to inherit host Material theming. `ImageCropView` accepts a host-provided path and returns normalized source-image geometry.

## 0.2 Rust processing

### `rust/`
The Rust crate is the deterministic image-processing boundary. It builds as `cdylib`, `staticlib`, and `rlib` and intentionally does not own camera lifecycle or OCR.

### `rust/src/model.rs`
`ProcessorOptions` describes orientation, ROI, grayscale, resize, and output encoding. Camera and Gallery both cross the Rust boundary using normalized source-image geometry.

ROI handling is pixel-stable: normalized raw ROI bounds are quantized once into integer half-open pixel coordinates, then those integer bounds are rotated exactly. This avoids floating-point complement drift at recurring normalized fractions such as `1/3`.

### `rust/src/processor.rs`
The current encoded-image pipeline is:
1. decode JPEG/PNG
2. normalize orientation
3. map/crop optional raw ROI
4. optional grayscale
5. optional no-upscale max-dimension resize
6. JPEG/PNG encode

Perspective correction is intentionally not part of this path yet.

### `rust/src/ffi.rs`
The C ABI accepts encoded input bytes and UTF-8 JSON options. Results use explicit Rust-owned buffers and must be released with `card_scan_result_free`. Panics are contained before crossing the FFI boundary. Public unsafe functions document pointer/lifetime/ownership requirements in `# Safety` sections and CI runs Clippy with warnings denied.

### `rust/src/detection.rs`
PR2 adds deterministic classical-CV quadrilateral detection without introducing OpenCV, ML, or another native CV dependency.

Detection stages:
1. convert source to grayscale working image
2. deterministic 3x3 box blur
3. Sobel gradient magnitude
4. adaptive threshold from gradient mean plus configurable standard-deviation multiplier
5. group edge pixels using 8-connected components
6. extract a convex hull for each viable component
7. approximate a four-corner quadrilateral using hull extrema
8. score each candidate and return the highest-scoring one

`detect_card_quad()` is deliberately separate from `process_encoded()`. It returns `DetectionResult`, containing normalized clockwise corners beginning at top-left plus a `CandidateScore` breakdown.

Score components are:
- **area** — candidate coverage relative to source area
- **rectangularity** — polygon area relative to its axis-aligned bounding rectangle
- **aspect ratio** — logarithmic similarity against an optional expected ratio; portrait rotation is treated equivalently
- **alignment** — preference toward the expected image/frame center
- **edge strength** — average component gradient normalized by strongest source gradient

The initial total uses fixed deterministic weights. These are implementation details for v0.2 and should be tuned against representative fixtures before being considered stable API behavior.

Tests cover centered-card detection, small-area rejection, portrait/landscape aspect equivalence, and convex-hull removal of interior points.

## Example application

`example/lib/main.dart` starts at `ExampleHomePage` with Camera and Gallery routes. `image_picker` is an example-only dependency. Camera controls remain orientation-aware and themable.

## Naming rule

`Dxtr`/`dxtr` belongs only to package/repository identity such as `dxtr_card_scan`. Dart domain classes, fields, helpers, tests, and UI labels remain neutral.

## Validation status

v0.1 physical-device validation passed on 2026-08-22. v0.2 PR1 Rust foundation merged as PR #3 with Rust format, Clippy, and tests in CI. PR2 detection must pass the same Rust gate before merge.

## Next walkthrough section

After detector validation, document perspective-warp geometry, detected-quad crop semantics, interpolation/border policy, output sizing, and then the Dart/native FFI packaging boundary.
