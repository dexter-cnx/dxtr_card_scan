# Architecture

## Product definition

Dxtr Card Scan is a Flutter/Dart capture SDK with a Rust-backed preprocessing core. It prepares card/document images for OCR but does not own the OCR engine.

## Boundary

### Flutter
- camera lifecycle and permissions through a host-selected camera implementation
- preview rendering
- customizable frame UI
- normalized geometry
- preview-to-captured-image mapping
- capture orchestration

### Rust (v0.2+)
1. normalize orientation
2. constrain detection to an ROI around the expected frame
3. edge detection and quadrilateral candidates
4. score candidates by area, rectangularity, expected aspect ratio, frame alignment, and edge strength
5. perspective correction
6. crop
7. optional grayscale/contrast normalization
8. optional resize
9. encode OCR-ready output

## Decisions

- OCR-engine agnostic.
- Normalized `[0,1]` geometry is the stable API boundary.
- Do not crop in Flutter before sensor/preview geometry is reconciled.
- Rust must not own camera lifecycle.
- Future `CardTemplate` will expose named normalized regions after perspective correction.
