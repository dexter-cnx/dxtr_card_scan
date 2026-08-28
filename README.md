# dxtr_card_scan

OCR-engine-agnostic Flutter card capture and preprocessing for Android, iOS, and macOS, backed by a Rust image-processing core.

The package owns capture UI, capture-frame geometry, gallery cropping, image preprocessing, quality analysis, and optional live-capture orchestration. OCR itself stays outside the package so applications can use any local or remote OCR engine.

## What it provides

- Camera capture with configurable ID-1 or custom frames.
- Portrait, landscape, and unrestricted orientation policies.
- Configurable frame alignment, padding, controls, labels, and themes.
- Gallery image selection and package-owned crop flow.
- Unified Camera + Gallery entry through `CardCameraGalleryCaptureView`.
- Optional host-injected native document-scanner fallback.
- Rust-backed card detection, perspective correction, enhancement, resize, JPEG/PNG encoding, and quality analysis.
- Capture profiles for OCR, fast, archival, and manual processing goals.
- Optional capture quality metadata.
- `CardTemplate` normalized regions and extraction from corrected images.
- Advanced live-analysis orchestration through a separate supported barrel.

## Installation

Add the package to your application:

```yaml
dependencies:
  dxtr_card_scan:
    git:
      url: https://github.com/dexter-cnx/dxtr_card_scan.git
```

The repository currently keeps `publish_to: none`; use the Git dependency until a registry release is intentionally published.

Minimum SDKs are Dart `>=3.4.0 <4.0.0` and Flutter `>=3.22.0`.

## Recommended integration

For most applications, start with the primary barrel:

```dart
import 'package:dxtr_card_scan/dxtr_card_scan.dart';
```

A unified Camera + Gallery surface can use the built-in OCR profile defaults:

```dart
CardCameraGalleryCaptureView(
  frame: const CaptureFrame.id1(
    widthFactor: .88,
    maxHeightFactor: .82,
  ),
  processOptions: CardCaptureProfile.ocr.processorOptions,
  cameraConfirmationMode: CaptureConfirmationMode.none,
  galleryConfirmationMode: CaptureConfirmationMode.afterCrop,
  onCompleted: (result) async {
    final processedPath = result.processed.path;
    final sourceRoi = result.sourceRoi;
    final quality = result.qualityMetadata;

    // Send processedPath to your OCR layer or continue locally.
  },
);
```

`CardCaptureResult` contains the original image, corrected crop, final processed image, normalized source ROI, and optional live quality metadata.

## Camera-only capture

Use `CardCaptureView` when the host wants a camera-only flow:

```dart
CardCaptureView(
  frame: const CaptureFrame.id1(widthFactor: .88),
  processOptions: CardCaptureProfile.ocr.processorOptions,
  confirmationMode: CaptureConfirmationMode.afterCrop,
  onCompleted: (result) async {
    print(result.processed.path);
  },
);
```

The package owns the `camera` plugin lifecycle for this surface. It does not require a host-provided camera preview or shutter callback.

## Gallery-only capture

Use `CardGalleryCaptureView` or `CardGalleryCropView` when the host already has an image path or only needs gallery input.

The normal example app demonstrates Camera + Gallery on Android/iOS and Gallery-only use on macOS.

## Capture profiles

`CardCaptureProfile` provides named processing defaults:

- `manual` — host-controlled processing without automatic perspective detection.
- `ocr` — perspective correction plus OCR-oriented enhancement.
- `fast` — lower-cost processing for latency-sensitive flows.
- `archival` — higher-fidelity PNG output.

All built-in profiles deliberately leave automatic shutter dispatch disabled. Automatic capture remains opt-in until physical calibration evidence establishes production thresholds and preview-to-stream geometry across supported device/orientation states.

## Capture geometry

The geometry layer does not assume preview pixels match captured-image pixels. `CameraGeometryMapper` and the related geometry types account for `BoxFit.cover`, capture rotation, mirroring, and normalized source ROI mapping.

When live camera-stream analysis is used, orientation/mirroring must be supplied explicitly through a `CardLiveStreamTransformResolver`. Unresolved transform states skip live analysis rather than guessing. Zoomed live analysis is also skipped until that geometry is physically calibrated.

## Quality analysis

The Rust processor exposes blur, exposure, card coverage, detection confidence, and advisory glare measurements. Dart also derives advisory perspective/alignment information from the detected quadrilateral.

Several measurements remain calibration-gated. Do not treat advisory values as production rejection thresholds unless your application has validated them on representative physical devices.

## CardTemplate

`CardTemplate` describes named normalized regions in the already perspective-corrected card coordinate space. `CardTemplateExtractor` decodes a corrected encoded image once and returns PNG bytes for each region in template order.

```dart
final template = CardTemplate(
  id: 'id-card',
  regions: const [
    CardTemplateRegion(
      name: 'name',
      rect: NormalizedRect(
        left: .30,
        top: .20,
        right: .90,
        bottom: .38,
      ),
    ),
  ],
);
```

The extracted regions can then be passed to any OCR engine.

## Advanced API

Lower-level live capture and orchestration contracts are intentionally separated from the primary compatibility surface:

```dart
import 'package:dxtr_card_scan/dxtr_card_scan_advanced.dart';
```

This barrel includes the primary API plus the live camera session, coordinator, analyzer, stability tracker, package capture pipeline, auto-capture policy, and live feedback controller/layer.

Use the advanced API when building custom live-capture orchestration. Prefer the primary barrel for ordinary application integration.

## Native scanner fallback

`CardCameraGalleryCaptureView` can accept a host implementation of `CardNativeScanner`. The package intentionally does not depend directly on VisionKit, ML Kit, or another scanner SDK. Multi-page results are fed through the existing gallery crop and processing flow in page order.

## Platform status

The native processor is packaged for Android, iOS, and macOS. CI builds:

- Android arm64 debug APK on Linux.
- iOS debug host on macOS with `--no-codesign`.
- macOS debug host on macOS.

These checks validate compile/link/package integration. They are not a substitute for physical-device camera and geometry validation. Fresh 1.0 physical validation remains a separate release gate and is tracked in `docs/1.0_PLATFORM_VALIDATION.md`.

## Example app

Run the standard example:

```sh
cd example
flutter pub get
flutter run
```

The standard example focuses on supported primary integration flows. Calibration evidence tooling uses a separate entrypoint and is intentionally not mixed into the user-facing example.

## Development

Run the repository checks with:

```sh
make ci
```

Processor benchmark methodology and the current reference baseline are documented in `docs/1.0_BENCHMARKS.md`.

## API compatibility

The 1.0 compatibility surface is defined by `lib/dxtr_card_scan.dart`. Supported lower-level integration contracts live in `lib/dxtr_card_scan_advanced.dart`.

The public API audit and stability decisions are documented in:

- `docs/1.0_PUBLIC_API_AUDIT.md`
- `docs/1.0_API_STABILITY_SIGNOFF.md`

## Additional documentation

- `docs/ARCHITECTURE.md`
- `docs/CODE_WALKTHROUGH.md`
- `docs/ROADMAP.md`
- `docs/PROJECT_HANDOFF.md`
- `docs/1.0_PLATFORM_VALIDATION.md`
- `docs/1.0_BENCHMARKS.md`

## License

See `LICENSE`.