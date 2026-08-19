# dxtr_card_scan

OCR-engine-agnostic Flutter card capture and preprocessing toolkit backed by a planned Rust processing core.

## Architecture

- Flutter owns camera lifecycle, preview UI, capture frame customization, and preview/image geometry.
- Rust owns card detection, perspective correction, crop, enhancement, resize, and encoding.
- OCR remains pluggable and outside the core package.

## v0.1 capture foundation

```dart
final controller = CardCaptureController();

CardCaptureView(
  controller: controller,
  frame: const CaptureFrame.id1(widthFactor: .88),
  previewBuilder: (_) => YourCameraPreview(),
  onCapture: () => yourCamera.takePicture(),
);
```

A fully custom frame can be supplied through `frameBuilder`. The geometry layer maps the visible preview region back into captured-image coordinates instead of assuming preview pixels match sensor pixels.

See `docs/ARCHITECTURE.md`, `docs/ROADMAP.md`, `docs/CODE_WALKTHROUGH.md`, and `docs/PROJECT_HANDOFF.md`.
