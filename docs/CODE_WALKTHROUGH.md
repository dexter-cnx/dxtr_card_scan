# Code Walkthrough

This document tracks the implementation as the package evolves. Update it with every material milestone.

## 0.1 Capture foundation

### `lib/dxtr_card_scan.dart`
The public barrel. `dxtr_card_scan` is the package/library identity; public Dart domain types intentionally avoid a package-name prefix.

### Geometry
`NormalizedRect` is the stable `[0,1]` geometry primitive. `CapturedImageTransform` maps displayed normalized geometry back to raw captured-image coordinates, including rotation and mirroring. `PreviewGeometry` handles `BoxFit.cover` preview-to-source mapping before that transform.

### Capture/theme/gallery
`CaptureFrame` supports ratio, size, alignment, and alignment padding. `CaptureOrientationPolicy` rejects capture without locking host orientation. `CardScanTheme` owns package-specific Camera/Gallery visuals. `ImageCropView` accepts a host-provided image path and returns normalized source-image geometry.

## 0.2 Rust processing

### `rust/`
The Rust crate is the deterministic image-processing boundary. It builds as `cdylib`, `staticlib`, and `rlib` and intentionally does not own camera lifecycle or OCR.

### `rust/src/model.rs`
`ProcessorOptions` currently describes:
- orientation normalization
- raw normalized ROI
- `auto_detect`
- optional normalized `perspective_quad`
- optional `warp_long_edge`
- optional OCR enhancement
- optional grayscale
- optional no-upscale max-dimension resize
- JPEG/PNG output

`auto_detect` and `perspective_quad` are mutually exclusive. A supplied perspective quad is relative to the current working image after orientation normalization and optional ROI crop.

ROI handling remains pixel-stable: normalized raw ROI bounds are quantized once into integer half-open pixel coordinates and then rotated exactly.

### `rust/src/processor.rs`
The encoded-image pipeline is now:
1. decode JPEG/PNG
2. quantize optional raw ROI
3. normalize orientation
4. rotate/crop optional ROI
5. either detect a card quad or use a supplied perspective quad
6. perspective warp/crop when a quad is present
7. optional OCR enhancement, otherwise optional grayscale
8. optional no-upscale max-dimension resize
9. JPEG/PNG encode

`enhance_for_ocr` is opt-in. It converts to grayscale and performs conservative 2nd/98th percentile contrast stretching. It is intentionally not a hard-threshold default.

### `rust/src/ffi.rs`
The C ABI accepts encoded input bytes and UTF-8 JSON options. Function signatures remain unchanged as options evolve. Results use explicit Rust-owned buffers and must be released with `card_scan_result_free`. Panics are contained before crossing the FFI boundary.

### `rust/src/detection.rs`
PR2 provides deterministic classical-CV quadrilateral detection without OpenCV or ML.

Detection stages:
1. grayscale working image
2. 3x3 box blur
3. Sobel gradient magnitude
4. adaptive threshold
5. reject zero-gradient/solid images
6. 8-connected edge components
7. convex hull extraction
8. four-distinct-corner approximation
9. candidate scoring

`detect_card_quad()` returns a cyclic clockwise `Quad` plus `CandidateScore`. The first corner is top-most, not a stable top-left semantic. This matters for rotated/diamond cards and is handled by the warp layer.

Score components are area, rectangularity, expected aspect-ratio similarity, center alignment, and edge strength.

### `rust/src/warp.rs`
PR3 adds deterministic perspective rectification.

`warp_quad()` accepts a normalized cyclic clockwise quad. It does not assume corner index 0 is top-left. The two opposite edge pairs are measured; if necessary the cyclic array is rotated so the longer pair forms output width. This keeps card output landscape-oriented while preserving winding.

Natural output width/height are the averages of opposite source edge lengths. `WarpOptions.output_long_edge` may override the long-edge pixel size while retaining aspect ratio.

The projective map is computed from the unit destination square to the source quadrilateral. Each destination pixel is inverse-mapped into source coordinates, then sampled with bilinear interpolation. Sampling is clamped to the source boundary. Degenerate and singular quadrilaterals return errors rather than producing undefined pixels.

Synthetic tests cover axis-aligned warp dimensions, portrait/diamond long-edge orientation, explicit output sizing, and degenerate quad rejection.

## Validation tooling

The Makefile provides both Flutter and Rust local gates. Rust targets are:
- `make rust-format`
- `make rust-format-check`
- `make rust-clippy`
- `make rust-test`
- `make rust-ci`

The top-level `make ci` includes `rust-ci` so formatting and Clippy failures can be caught before push.

## Example application

`example/lib/main.dart` starts at `ExampleHomePage` with Camera and Gallery routes. `image_picker` remains an example-only dependency. Native Rust processing is not wired into Flutter yet; that is the next v0.2 PR after the Rust contract is stable.

## Naming rule

`Dxtr`/`dxtr` belongs only to package/repository identity such as `dxtr_card_scan`. Dart domain classes, fields, helpers, tests, and UI labels remain neutral.

## Validation status

v0.1 physical-device validation passed on 2026-08-22. v0.2 PR1 Rust foundation merged as PR #3. v0.2 PR2 deterministic detection merged as PR #4 after regression fixes for solid-color false positives and 45-degree rectangle corner ties. PR3 must pass Rust format, Clippy, and tests before merge.

## Next walkthrough section

After PR3, document Dart FFI DTOs, native-library loading/packaging per platform, Flutter error mapping, example processor integration, and physical-device validation.
