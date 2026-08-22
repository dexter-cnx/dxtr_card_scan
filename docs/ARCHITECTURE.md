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
- explicit rotation/mirroring metadata
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

## Geometry contract

The capture frame is measured in viewport space but the processing boundary uses normalized coordinates in the raw captured image.

Mapping order:

```text
viewport frame
  -> BoxFit.cover displayed-image rectangle
  -> normalized displayed-image rectangle
  -> undo horizontal preview mirroring
  -> undo preview rotation
  -> normalized raw captured-image ROI
```

`CapturedImageTransform.quarterTurnsClockwise` describes the rotation that turns the raw captured image into the displayed preview orientation. `mirrored` describes a horizontal mirror applied after that rotation. Mapping to raw coordinates inverts those operations in reverse order.

## Decisions

- OCR-engine agnostic.
- Normalized `[0,1]` geometry is the stable processing boundary.
- Do not crop in Flutter before sensor/preview geometry is reconciled.
- Rust must not own camera lifecycle.
- Camera orientation and mirroring are explicit inputs, never hidden assumptions.
- Future `CardTemplate` will expose named normalized regions after perspective correction.
