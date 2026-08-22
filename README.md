# dxtr_card_scan

OCR-engine-agnostic Flutter card capture and preprocessing toolkit with a Rust processing core planned for v0.2.

## Architecture

- Flutter owns camera lifecycle, preview UI, capture-frame customization, and preview/image geometry.
- Rust owns card detection, perspective correction, crop, enhancement, resize, and encoding.
- OCR remains pluggable and outside the core package.

## Capture foundation

```dart
final controller = CardCaptureController();

CardCaptureView(
  controller: controller,
  frame: const CaptureFrame.id1(widthFactor: .88),
  previewBuilder: (_) => YourCameraPreview(),
  onCapture: () => yourCamera.takePicture(),
);
```

A fully custom frame can be supplied through `frameBuilder`.

The geometry layer does not assume preview pixels match captured-image pixels. It accounts for `BoxFit.cover`, sensor/captured-image rotation, and horizontal preview mirroring before producing a normalized raw-image ROI for the future Rust processor.

```dart
final geometry = PreviewGeometry(
  viewportSize: viewportSize,
  imageSize: rawImageSize,
  transform: const CapturedImageTransform(
    quarterTurnsClockwise: 1,
    mirrored: false,
  ),
);

final roi = geometry.viewportRectToNormalizedImage(frameRect);
```

## Development

```sh
make ci
```

The `example/` app uses Flutter's official `camera` plugin and is intended for the first real-device capture validation.

See `docs/ARCHITECTURE.md`, `docs/ROADMAP.md`, `docs/CODE_WALKTHROUGH.md`, and `docs/PROJECT_HANDOFF.md`.
