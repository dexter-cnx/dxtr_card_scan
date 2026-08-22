# Project Handoff

Last updated: 2026-08-22

## Project

Repository: `dexter-cnx/dxtr_card_scan`

`dxtr_card_scan` is an OCR-engine-agnostic Flutter/Dart SDK for card/document capture plus deterministic Rust preprocessing. Flutter owns camera/UI/preview geometry. Rust owns raster processing.

## Architecture rules

1. Core does not embed an OCR engine.
2. Rust does not own camera lifecycle/UI.
3. Preview/frame geometry is normalized before processing.
4. Rotation/mirroring is explicit.
5. File picking stays in the host/example.
6. Grayscale/OCR enhancement remains opt-in.
7. `Dxtr`/`dxtr` is reserved for package/repository identity; public Dart domain types remain neutral.
8. v0.2 detection remains deterministic classical CV.
9. `perspective_quad` is interpreted after orientation normalization and optional ROI crop.
10. Camera detection should be constrained by the capture-frame ROI before auto-detect so unrelated high-contrast background edges do not dominate quadrilateral selection.
11. Perspective-warp canonicalization must preserve the source top direction after long-edge normalization so cyclic quad start index cannot introduce a 180-degree output flip.
12. CPU-heavy image decode/orientation work and synchronous native FFI processing should run off Flutter's UI isolate in the example integration flow.
13. Desktop-selected files are treated as read-only inputs; normalized/intermediate files are written under app/system temporary storage rather than beside the selected source file.

## Current branch / PR

Branch: `agent/v0.2-example-native-flow`
PR: #7

## Completed

### v0.1 capture foundation

Merged and physical-device validated on 2026-08-22. Camera/Gallery navigation, portrait/landscape controls, flash, torch, pinch zoom, capture-frame alignment/padding, orientation policies, Gallery crop, and `CardScanTheme` passed on device.

### v0.2 PR1 — Rust processor foundation

Merged as PR #3. Includes JPEG/PNG decode, orientation normalization, pixel-stable ROI mapping/crop, optional grayscale/resize, encoding, stable C ABI, result ownership/free contract, and panic containment.

### v0.2 PR2 — quadrilateral detection

Merged as PR #4. Includes grayscale/blur/Sobel/adaptive threshold, flat-image rejection, connected components, convex hull, distinct-corner quad approximation, deterministic scoring, and 45-degree regression coverage.

### v0.2 PR3 — perspective warp / OCR enhancement

Merged as PR #5. Includes deterministic projective warp, bilinear sampling, cyclic-quad handling, long-edge-first output, bounded `warp_long_edge` (`2..=4096`), auto-detect/manual quad integration, conservative percentile OCR enhancement, and regression coverage for tiny images/allocation bounds.

### v0.2 PR4 — Dart FFI + native packaging

Merged as PR #6. Includes:
- public `CardScanProcessor`
- `processBytes()` and `processFile()`
- `CardScanProcessorException` native status/error mapping
- UTF-8 JSON option transport
- `CardScanProcessorOptions`, `ProcessorQuad`, `ProcessorPoint`, `ProcessorOutputFormat`
- Android `ffiPlugin` packaging through Gradle/CMake -> Cargo per ABI
- iOS/macOS `ffiPlugin` packaging through CocoaPods/Xcode -> Cargo per active architecture
- Darwin universal staticlib creation and force-load linkage inside the plugin Pod target
- Flutter >=3.22 compatibility retained with AGP 7.4.2
- processor option JSON contract tests

## v0.2 PR5 — integrated native flow

**Validation complete on `agent/v0.2-example-native-flow` as PR #7; awaiting final CI/review and merge.**

Physical Android validation on 2026-08-22 proved:
- Rust native library loads on device
- Dart FFI calls Rust successfully
- Rust decode/process/encode returns bytes
- Flutter renders the processed bytes
- integrated Camera output no longer flips upside down after warp canonicalization was fixed on device
- Camera frame ROI / warp behavior is acceptable on device
- zoom / flash / torch / Camera controls regressions did not reproduce
- updated Gallery shows a responsive loading state after picking an image
- crop interaction remains stable with system/predictive-back blocked on the crop route
- Gallery `Scan selection` performs perspective correction successfully
- Gallery processed preview remains color instead of looking like an OCR-enhanced grayscale crop

Physical iPhone 11 validation on 2026-08-22 proved:
- iOS example builds and launches on a physical device
- Camera capture succeeds
- CocoaPods/Xcode builds and links the Rust static library successfully for `iphoneos`
- Dart FFI invokes the Rust processor on-device
- processed output is returned and displayed successfully
- Gallery still works after the isolate/refactor change: image preparation, crop, native scan processing, perspective correction, and processed preview all complete successfully

macOS validation on 2026-08-22 proved:
- generated macOS example host builds and launches
- native Rust archive is built and linked successfully through the plugin Pod target
- desktop Gallery uses `file_selector` so folders can be browsed and image files selected through the native open panel
- selected sandbox files remain read-only inputs while normalized images are written to temporary storage
- Gallery crop, native FFI/Rust processing, perspective correction, and processed preview complete successfully

Integration fixes discovered during physical validation:
1. Camera JPEG/display orientation and warp cyclic-start ambiguity could produce upside-down output; EXIF is baked and warp canonicalization now preserves source-top direction.
2. Whole-frame auto detection could select background geometry; Camera detection is constrained to the capture-frame ROI.
3. Gallery preparation/native processing on the UI isolate could appear frozen; CPU/native work now uses `Isolate.run()`.
4. Android predictive-back could interfere with crop gestures; the crop route blocks system back and uses explicit Close navigation.
5. Gallery originally behaved like ROI crop + grayscale enhancement; it now runs ROI -> auto-detect -> perspective warp -> encode and preserves color by default.
6. Darwin Runner-level `-force_load` caused generated archive ordering failures; force-load now belongs to the plugin Pod target that owns the Rust build phase.
7. macOS sandbox prevented writing normalized files beside user-selected sources; intermediates now use system temporary storage.

Current Gallery implementation:
- Android/iOS picker: `image_picker`
- macOS picker: `file_selector`
- `example/lib/background_scan_tasks.dart` runs image decode/EXIF bake and synchronous FFI/Rust processing through `Isolate.run()`
- Gallery shows a blocking progress overlay and status text while preparing or processing
- Gallery crop route uses `PopScope` to block device/system back gestures; leaving the page is explicit through its Close button
- Gallery `Scan selection` runs `ROI -> auto-detect -> perspective warp -> encode`
- Gallery preview keeps color by default (`enhanceForOcr: false`); OCR enhancement remains opt-in processor behavior

Additional native packaging state:
- iOS/macOS podspec script phases declare the generated Rust archive as an Xcode output
- generated iOS example signing uses Development Team `ZTM9BCJPY9`
- example host bootstrap generates Android, iOS, and macOS scaffolding
- macOS validation skips Camera initialization and targets Gallery/native processing

## Remaining before v0.2 completion

1. Confirm PR #7 CI/review state is clean.
2. Merge PR #7 and record the final merge SHA.
3. Close v0.2 and proceed to v0.3 quality analysis.

## Native build policy

The package keeps Flutter >=3.22 compatibility, so native packaging uses the legacy FFI-plugin platform build layout rather than requiring Flutter 3.38+ Native Assets build hooks. No native binary is committed to git.

Generated native build state such as `android/.cxx/`, platform example host folders, and `rust/target/` is ignored. `rust/Cargo.lock` should remain committed because Rust is an embedded native implementation and reproducible dependency resolution is desirable.

`make install-hooks` installs the tracked pre-push guard. It runs Dart/Rust formatting and Rust validation locally before push.

## Documentation policy

Keep `docs/PROJECT_HANDOFF.md`, `docs/CODE_WALKTHROUGH.md`, and `docs/ROADMAP.md` synchronized for material architecture/native-processing changes.
